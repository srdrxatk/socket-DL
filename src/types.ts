export enum ChainId {
  GOERLI = 5,
  MUMBAI = 80001,
  ARBITRUM_TESTNET = 421613,
  OPTIMISM_TESTNET = 420,
  BSC_TESTNET = 97,
  MAINNET = 1,
  POLYGON = 137,
  ARBITRUM = 42161,
  OPTIMISM = 10,
  BSC = 56,
}

export const TestnetIds: ChainId[] = [
  ChainId.GOERLI,
  ChainId.MUMBAI,
  ChainId.ARBITRUM_TESTNET,
  ChainId.OPTIMISM_TESTNET,
  ChainId.BSC_TESTNET,
];

export const L1Ids: ChainId[] = [ChainId.MAINNET, ChainId.GOERLI];

export const MainnetIds: ChainId[] = (
  Object.values(ChainId) as ChainId[]
).filter((c) => !TestnetIds.includes(c));

export const L2Ids: ChainId[] = [
  ChainId.MUMBAI,
  ChainId.ARBITRUM_TESTNET,
  ChainId.OPTIMISM_TESTNET,
  ChainId.POLYGON,
  ChainId.ARBITRUM,
  ChainId.OPTIMISM,
];

export enum IntegrationTypes {
  fast = "FAST",
  optimistic = "OPTIMISTIC",
  native = "NATIVE_BRIDGE",
}

export type Integrations = { [chainId in ChainId]?: ChainAddresses };
export type ChainAddresses = { [integration in IntegrationTypes]?: Configs };
export type Configs = {
  switchboard?: string;
  capacitor?: string;
  decapacitor?: string;
};

export interface ChainSocketAddresses {
  Counter: string;
  CapacitorFactory: string;
  ExecutionManager: string;
  GasPriceOracle: string;
  Hasher: string;
  SignatureVerifier: string;
  Socket: string;
  TransmitManager: string;
  integrations?: Integrations;
}

export type DeploymentAddresses = {
  [chainId in ChainId]?: ChainSocketAddresses;
};

export enum NativeSwitchboard {
  NON_NATIVE = 0,
  ARBITRUM_L1 = 1,
  ARBITRUM_L2 = 2,
  OPTIMISM = 3,
  POLYGON_L1 = 4,
  POLYGON_L2 = 5,
}
