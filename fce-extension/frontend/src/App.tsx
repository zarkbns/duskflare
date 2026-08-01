import { useAccount, useConnect, useDisconnect, useWriteContract } from 'wagmi';
import { injected } from 'wagmi/connectors';
import addresses from '../../deployed-addresses.json';
import instructionSenderData from '../../out/InstructionSender.sol/InstructionSender.json';

export default function App() {
  const { address, isConnected } = useAccount();
  const { connect } = useConnect();
  const { disconnect } = useDisconnect();
  const { writeContract, isPending, isSuccess, error } = useWriteContract();

            const handleSendInstruction = () => {
                writeContract({
                      chainId: 114, 
                            address: addresses.InstructionSender as `0x${string}`, 
                                  abi: instructionSenderData.abi,
                                        functionName: 'matchOrder',
                                              args: ["0x1234"], 
                                                  });
                                                    };

                                                      return (
                                                          <div style={{ padding: '20px', fontFamily: "'Inter', sans-serif" }}>
                                                                <h2 style={{ fontFamily: "'Comfortaa', sans-serif" }}>Dusk TEE Frontend (Coston2)</h2>
                                                                      
                                                                            <div style={{ marginBottom: '20px' }}>
                                                                                    {isConnected ? (
                                                                                              <div>
                                                                                                          <p><strong>Connected:</strong> {address}</p>
                                                                                                                      <button onClick={() => disconnect()} style={{ padding: '8px 16px', cursor: 'pointer' }}>Disconnect</button>
                                                                                                                                </div>
                                                                                                                                        ) : (
                                                                                                                                                  <button onClick={() => connect({ connector: injected() })} style={{ padding: '8px 16px', cursor: 'pointer' }}>
                                                                                                                                                              Connect Wallet
                                                                                                                                                                        </button>
                                                                                                                                                                                )}
                                                                                                                                                                                      </div>

                                                                                                                                                                                            {isConnected && (
                                                                                                                                                                                                    <div style={{ padding: '20px', border: '1px solid #ccc', borderRadius: '8px' }}>
                                                                                                                                                                                                              <h3 style={{ fontFamily: "'Comfortaa', sans-serif" }}>Instruction Sender</h3>
                                                                                                                                                                                                                        
                                                                                                                                                                                                                                  <p style={{ wordBreak: 'break-all' }}>
                                                                                                                                                                                                                                              <strong>Contract:</strong> {addresses.InstructionSender ? addresses.InstructionSender : <span style={{ color: 'red' }}>NOT FOUND - Check deployed-addresses.json!</span>}
                                                                                                                                                                                                                                                        </p>
                                                                                                                                                                                                                                                                  
                                                                                                                                                                                                                                                                            <button 
                                                                                                                                                                                                                                                                                        onClick={handleSendInstruction}
                                                                                                                                                                                                                                                                                                    disabled={isPending || !addresses.InstructionSender}
                                                                                                                                                                                                                                                                                                                style={{ 
                                                                                                                                                                                                                                                                                                                              padding: '10px 20px', 
                                                                                                                                                                                                                                                                                                                                            cursor: (isPending || !addresses.InstructionSender) ? 'not-allowed' : 'pointer' 
                                                                                                                                                                                                                                                                                                                                                        }}
                                                                                                                                                                                                                                                                                                                                                                  >
                                                                                                                                                                                                                                                                                                                                                                              {isPending ? 'Sending...' : 'Send Instruction to TEE Proxy'}
                                                                                                                                                                                                                                                                                                                                                                                        </button>

                                                                                                                                                                                                                                                                                                                                                                                                  {isSuccess && <p style={{ color: 'green', marginTop: '15px', fontWeight: 'bold' }}>Transaction Sent Successfully!</p>}
                                                                                                                                                                                                                                                                                                                                                                                                            {error && <p style={{ color: 'red', marginTop: '15px', wordBreak: 'break-all' }}>Error: {error.message}</p>}
                                                                                                                                                                                                                                                                                                                                                                                                                    </div>
                                                                                                                                                                                                                                                                                                                                                                                                                          )}
                                                                                                                                                                                                                                                                                                                                                                                                                              </div>
                                                                                                                                                                                                                                                                                                                                                                                                                                );
                                                                                                                                                                                                                                                                                                                                                                                                                                }