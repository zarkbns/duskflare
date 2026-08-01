import { http, createConfig } from 'wagmi'
import { defineChain } from 'viem'
import { injected } from 'wagmi/connectors'

// Explicitly define Coston2
export const coston2 = defineChain({
  id: 114,
    name: 'Flare Testnet Coston2',
      nativeCurrency: {
          decimals: 18,
              name: 'Coston2 Flare',
                  symbol: 'C2FLR',
                    },
                      rpcUrls: {
                          default: { http: ['https://coston2-api.flare.network/ext/C/rpc'] },
                            },
                              blockExplorers: {
                                  default: { name: 'Explorer', url: 'https://coston2-explorer.flare.network' },
                                    },
                                    })

                                    export const config = createConfig({
                                      chains: [coston2],
                                        connectors: [injected()],
                                          transports: {
                                              [coston2.id]: http(),
                                                },
                                                })