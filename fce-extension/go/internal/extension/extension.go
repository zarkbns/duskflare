package extension

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"

	"sign-extension/internal/config"
	"sign-extension/pkg/types"

	"github.com/flare-foundation/go-flare-common/pkg/tee/instruction"
	teetypes "github.com/flare-foundation/tee-node/pkg/types"
	teeutils "github.com/flare-foundation/tee-node/pkg/utils"

	"github.com/flare-foundation/tee-node/pkg/processorutils"

	secp256k1 "github.com/decred/dcrd/dcrec/secp256k1/v4"
)

// Extension holds mutable state for the sign extension. Access is serialized
// by the mutex; the framework dispatches actions serially anyway, but the
// state read in stateHandler is concurrent with action processing.
type Order struct {
	OrderID string `json:"orderId"`
	Pair    string `json:"pair"`
	Side    string `json:"side"`
	Amount  string `json:"amount"`
}

type Extension struct {
	mu     sync.RWMutex
	Server *http.Server

	// signPort is the TEE node's /decrypt endpoint port, used by handleKeyUpdate.
	signPort int

	// privateKey is the secp256k1 private key delivered via UPDATE_KEY. May be nil
	// before the first successful UPDATE_KEY instruction.
	privateKey *secp256k1.PrivateKey

	// openOrders holds unmatched orders awaiting a counterpart, keyed by trading pair.
	openOrders map[string][]Order
}

// --- DO NOT MODIFY: New(), actionHandler() are boilerplate.
func New(extensionPort, signPort int) *Extension {
	e := &Extension{signPort: signPort, openOrders: make(map[string][]Order)}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /state", e.stateHandler)
	mux.HandleFunc("POST /action", e.actionHandler)

	e.Server = &http.Server{Addr: fmt.Sprintf(":%d", extensionPort), Handler: mux}
	return e
}

// stateHandler reports whether a key is stored, without exposing the key.
func (e *Extension) stateHandler(w http.ResponseWriter, r *http.Request) {
	e.mu.RLock()
	stateResponse := types.StateResponse{
		StateVersion: teeutils.ToHash(config.Version),
		State: types.State{
			HasKey: e.privateKey != nil,
		},
	}
	e.mu.RUnlock()

	err := json.NewEncoder(w).Encode(stateResponse)
	if err != nil {
		http.Error(w, fmt.Sprintf("sending response: %v", err), http.StatusInternalServerError)
		return
	}
}

func (e *Extension) processAction(action teetypes.Action) (int, []byte) {
	dataFixed, err := processorutils.Parse[instruction.DataFixed](action.Data.Message)
	if err != nil {
		return http.StatusBadRequest, []byte(fmt.Sprintf("decoding fixed data: %v", err))
	}

	switch {
	case dataFixed.OPType == teeutils.ToHash(config.OPTypeKey):
		return e.processKey(action, dataFixed)


		case dataFixed.OPType == teeutils.ToHash(config.OPTypeOrder):
			return e.processOrder(action, dataFixed)
	default:
		return http.StatusNotImplemented, []byte(fmt.Sprintf(
			"unsupported op type: received %s, expected %s (%s)",
			dataFixed.OPType.Hex(), teeutils.ToHash(config.OPTypeKey).Hex(), config.OPTypeKey,
		))
	}
}

// processKey routes KEY instructions by OPCommand (UPDATE or SIGN).
func (e *Extension) processKey(action teetypes.Action, df *instruction.DataFixed) (int, []byte) {
	switch {
	case df.OPCommand == teeutils.ToHash(config.OPCommandUpdate):
		ar := e.processKeyUpdate(action, df)
		b, _ := json.Marshal(ar)
		return http.StatusOK, b

	case df.OPCommand == teeutils.ToHash(config.OPCommandSign):
		ar := e.processKeySign(action, df)
		b, _ := json.Marshal(ar)
		return http.StatusOK, b

	default:
		return http.StatusNotImplemented, []byte(fmt.Sprintf(
			"unsupported op command: received %s, expected one of [%s (%s), %s (%s)]",
			df.OPCommand.Hex(),
			teeutils.ToHash(config.OPCommandUpdate).Hex(), config.OPCommandUpdate,
			teeutils.ToHash(config.OPCommandSign).Hex(), config.OPCommandSign,
		))
	}
}

// processKeyUpdate decrypts the original message via the TEE node and stores
// the resulting bytes as a secp256k1 private key.
func (e *Extension) processKeyUpdate(action teetypes.Action, df *instruction.DataFixed) teetypes.ActionResult {
	if len(df.OriginalMessage) == 0 {
		return buildResult(action, df, nil, 0, fmt.Errorf("originalMessage is empty"))
	}

	keyBytes, err := decryptViaNode(e.signPort, df.OriginalMessage)
	if err != nil {
		return buildResult(action, df, nil, 0, fmt.Errorf("decryption failed: %v", err))
	}

	privKey, err := parseSecp256k1PrivateKey(keyBytes)
	if err != nil {
		return buildResult(action, df, nil, 0, fmt.Errorf("invalid private key: %v", err))
	}

	e.mu.Lock()
	e.privateKey = privKey
	e.mu.Unlock()

	return buildResult(action, df, nil, 1, nil)
}

// processKeySign signs the original message with the stored private key.
// Returns ABI-encoded (bytes message, bytes signature) in ActionResult.Data.
func (e *Extension) processKeySign(action teetypes.Action, df *instruction.DataFixed) teetypes.ActionResult {
	e.mu.RLock()
	key := e.privateKey
	e.mu.RUnlock()

	if key == nil {
		return buildResult(action, df, nil, 0, fmt.Errorf("no private key stored"))
	}
	if len(df.OriginalMessage) == 0 {
		return buildResult(action, df, nil, 0, fmt.Errorf("originalMessage is empty"))
	}

	sig, err := signECDSA(key, df.OriginalMessage)
	if err != nil {
		return buildResult(action, df, nil, 0, fmt.Errorf("signing failed: %v", err))
	}

	encoded, err := abiEncodeTwo(df.OriginalMessage, sig)
	if err != nil {
		return buildResult(action, df, nil, 0, fmt.Errorf("ABI encoding failed: %v", err))
	}

	return buildResult(action, df, encoded, 1, nil)
}


// processOrder routes ORDER instructions by OPCommand (MATCH).
func (e *Extension) processOrder(action teetypes.Action, df *instruction.DataFixed) (int, []byte) {
switch {
case df.OPCommand == teeutils.ToHash(config.OPCommandMatch):
ar := e.processOrderMatch(action, df)
b, _ := json.Marshal(ar)
return http.StatusOK, b

default:
return http.StatusNotImplemented, []byte(fmt.Sprintf(
"unsupported op command: received %s, expected %s (%s)",
df.OPCommand.Hex(), teeutils.ToHash(config.OPCommandMatch).Hex(), config.OPCommandMatch,
))
}
}

// processOrderMatch decrypts the incoming order payload inside the enclave.
func (e *Extension) processOrderMatch(action teetypes.Action, df *instruction.DataFixed) teetypes.ActionResult {
	if len(df.OriginalMessage) == 0 {
		return buildResult(action, df, nil, 0, fmt.Errorf("order payload is empty"))
	}

	orderBytes, err := decryptViaNode(e.signPort, df.OriginalMessage)
	if err != nil {
		return buildResult(action, df, nil, 0, fmt.Errorf("order decryption failed: %v", err))
	}

	var incoming Order
	if err := json.Unmarshal(orderBytes, &incoming); err != nil {
		return buildResult(action, df, nil, 0, fmt.Errorf("invalid order format: %v", err))
	}
	if incoming.Pair == "" || incoming.Side == "" || incoming.Amount == "" {
		return buildResult(action, df, nil, 0, fmt.Errorf("order missing required fields"))
	}

	e.mu.Lock()
	defer e.mu.Unlock()

	book := e.openOrders[incoming.Pair]
	oppositeSide := "sell"
	if incoming.Side == "sell" {
		oppositeSide = "buy"
	}

	for i, existing := range book {
		if existing.Side == oppositeSide && existing.Amount == incoming.Amount {
			// Match found: remove the resting order, do not add the incoming one.
			e.openOrders[incoming.Pair] = append(book[:i], book[i+1:]...)

			settleMsg := []byte(fmt.Sprintf("SETTLE:%s:%s:%s", incoming.Pair, incoming.Amount, existing.OrderID))

			var sigHex string
			if e.privateKey != nil {
				if sig, err := signECDSA(e.privateKey, settleMsg); err == nil {
					sigHex = fmt.Sprintf("%x", sig)
				}
			}

			matchResult := struct {
				Matched       bool   `json:"matched"`
				IncomingSide  string `json:"incomingSide"`
				MatchedWith   string `json:"matchedWith"`
				Pair          string `json:"pair"`
				Amount        string `json:"amount"`
				SettlementSig string `json:"settlementSig,omitempty"`
			}{true, incoming.Side, existing.OrderID, incoming.Pair, incoming.Amount, sigHex}

			encoded, err := json.Marshal(matchResult)
			if err != nil {
				return buildResult(action, df, nil, 0, fmt.Errorf("encoding match result failed: %v", err))
			}
			return buildResult(action, df, encoded, 1, nil)
		}
	}

	// No match: rest the incoming order in the book.
	e.openOrders[incoming.Pair] = append(book, incoming)

	noMatchResult := struct {
		Matched bool   `json:"matched"`
		Status  string `json:"status"`
		Pair    string `json:"pair"`
	}{false, "resting", incoming.Pair}

	encoded, err := json.Marshal(noMatchResult)
	if err != nil {
		return buildResult(action, df, nil, 0, fmt.Errorf("encoding rest result failed: %v", err))
	}
	return buildResult(action, df, encoded, 1, nil)
}

