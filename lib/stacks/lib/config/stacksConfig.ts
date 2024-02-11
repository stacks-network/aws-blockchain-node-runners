import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as configTypes from "./stacksConfig.interface";
import * as constants from "../../../constructs/constants";


const parseDataVolumeType = (dataVolumeType: string) => {
    switch (dataVolumeType) {
        case "gp3":
            return ec2.EbsDeviceVolumeType.GP3;
        case "io2":
            return ec2.EbsDeviceVolumeType.IO2;
        case "io1":
            return ec2.EbsDeviceVolumeType.IO1;
        case "instance-store":
            return constants.InstanceStoreageDeviceVolumeType;
        default:
            return ec2.EbsDeviceVolumeType.GP3;
    }
}

export const baseConfig: configTypes.StacksBaseConfig = {
    accountId: process.env.AWS_ACCOUNT_ID || "xxxxxxxxxxx",
    region: process.env.AWS_REGION || "us-east-2",
}

export const baseNodeConfig: configTypes.StacksBaseNodeConfig = {
    instanceType: new ec2.InstanceType(process.env.STACKS_INSTANCE_TYPE ? process.env.STACKS_INSTANCE_TYPE : "r6a.8xlarge"),
    instanceCpuType: process.env.STACKS_CPU_TYPE?.toLowerCase() == "x86_64" ? ec2.AmazonLinuxCpuType.X86_64 : ec2.AmazonLinuxCpuType.ARM_64,
    stacksCluster: <configTypes.StacksCluster> process.env.STACKS_CLUSTER || "mainnet-beta",
    stacksVersion: process.env.STACKS_VERSION || "1.16.15",
    nodeConfiguration: <configTypes.StacksNodeConfiguration> process.env.STACKS_NODE_CONFIGURATION || "baserpc",
    dataVolume: {
        sizeGiB: process.env.STACKS_DATA_VOL_SIZE ? parseInt(process.env.STACKS_DATA_VOL_SIZE): 2000,
        type: parseDataVolumeType(process.env.STACKS_DATA_VOL_TYPE?.toLowerCase() ? process.env.STACKS_DATA_VOL_TYPE?.toLowerCase() : "gp3"),
        iops: process.env.STACKS_DATA_VOL_IOPS ? parseInt(process.env.STACKS_DATA_VOL_IOPS): 12000,
        throughput: process.env.STACKS_DATA_VOL_THROUGHPUT ? parseInt(process.env.STACKS_DATA_VOL_THROUGHPUT): 700,
    },
    accountsVolume: {
        sizeGiB: process.env.STACKS_ACCOUNTS_VOL_SIZE ? parseInt(process.env.STACKS_ACCOUNTS_VOL_SIZE): 500,
        type: parseDataVolumeType(process.env.STACKS_ACCOUNTS_VOL_TYPE?.toLowerCase() ? process.env.STACKS_ACCOUNTS_VOL_TYPE?.toLowerCase() : "gp3"),
        iops: process.env.STACKS_ACCOUNTS_VOL_IOPS ? parseInt(process.env.STACKS_ACCOUNTS_VOL_IOPS): 6000,
        throughput: process.env.STACKS_ACCOUNTS_VOL_THROUGHPUT ? parseInt(process.env.STACKS_ACCOUNTS_VOL_THROUGHPUT): 700,
    },
    stacksNodeIdentitySecretARN: process.env.STACKS_NODE_IDENTITY_SECRET_ARN || "none",
    voteAccountSecretARN: process.env.STACKS_VOTE_ACCOUNT_SECRET_ARN || "none",
    authorizedWithdrawerAccountSecretARN: process.env.STACKS_AUTHORIZED_WITHDRAWER_ACCOUNT_SECRET_ARN || "none",
    registrationTransactionFundingAccountSecretARN: process.env.STACKS_REGISTRATION_TRANSACTION_FUNDING_ACCOUNT_SECRET_ARN || "none",
};

export const haNodeConfig: configTypes.StacksHAConfig = {
    albHealthCheckGracePeriodMin: process.env.STACKS_HA_ALB_HEALTHCHECK_GRACE_PERIOD_MIN ? parseInt(process.env.STACKS_HA_ALB_HEALTHCHECK_GRACE_PERIOD_MIN) : 10,
    heartBeatDelayMin: process.env.STACKS_HA_NODES_HEARTBEAT_DELAY_MIN ? parseInt(process.env.STACKS_HA_NODES_HEARTBEAT_DELAY_MIN) : 40,
    numberOfNodes: process.env.STACKS_HA_NUMBER_OF_NODES ? parseInt(process.env.STACKS_HA_NUMBER_OF_NODES) : 2,
};
