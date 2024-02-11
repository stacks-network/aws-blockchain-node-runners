import * as configTypes from "../../../constructs/config.interface";

export type StacksCluster = "mainnet-beta" | "testnet" | "devnet";
export type StacksNodeConfiguration = "consensus" | "baserpc" | "extendedrpc";

export interface StacksDataVolumeConfig extends configTypes.DataVolumeConfig {
}

export interface StacksAccountsVolumeConfig extends configTypes.DataVolumeConfig {
}

export interface StacksBaseConfig extends configTypes.BaseConfig {
}

export interface StacksBaseNodeConfig extends configTypes.BaseNodeConfig {
    stacksCluster: StacksCluster;
    stacksVersion: string;
    nodeConfiguration: StacksNodeConfiguration;
    dataVolume: StacksDataVolumeConfig;
    accountsVolume: StacksAccountsVolumeConfig;
    stacksNodeIdentitySecretARN: string;
    voteAccountSecretARN: string;
    authorizedWithdrawerAccountSecretARN: string;
    registrationTransactionFundingAccountSecretARN: string;
}

export interface StacksHAConfig {
    albHealthCheckGracePeriodMin: number;
    heartBeatDelayMin: number;
    numberOfNodes: number;
}
