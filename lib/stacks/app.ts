#!/usr/bin/env node
import 'dotenv/config'
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import * as nag from "cdk-nag";
import * as config from "./lib/config/stacksConfig";

import { StacksSingleNodeStack } from "./lib/single-node-stack";
import { StacksCommonStack } from "./lib/common-stack";
import { StacksHANodesStack } from "./lib/ha-nodes-stack";

const app = new cdk.App();
cdk.Tags.of(app).add("Project", "AWSStacks");

new StacksCommonStack(app, "stacks-common", {
    stackName: `stacks-nodes-common`,
    env: { account: config.baseConfig.accountId, region: config.baseConfig.region },
});

new StacksSingleNodeStack(app, "stacks-single-node", {
    stackName: `stacks-single-node-${config.baseNodeConfig.nodeConfiguration}`,
    env: { account: config.baseConfig.accountId, region: config.baseConfig.region },

    instanceType: config.baseNodeConfig.instanceType,
    instanceCpuType: config.baseNodeConfig.instanceCpuType,
    stacksCluster: config.baseNodeConfig.stacksCluster,
    stacksVersion: config.baseNodeConfig.stacksVersion,
    nodeConfiguration: config.baseNodeConfig.nodeConfiguration,
    dataVolume: config.baseNodeConfig.dataVolume,
    accountsVolume: config.baseNodeConfig.accountsVolume,
    stacksNodeIdentitySecretARN: config.baseNodeConfig.stacksNodeIdentitySecretARN,
    voteAccountSecretARN: config.baseNodeConfig.voteAccountSecretARN,
    authorizedWithdrawerAccountSecretARN: config.baseNodeConfig.authorizedWithdrawerAccountSecretARN,
    registrationTransactionFundingAccountSecretARN: config.baseNodeConfig.registrationTransactionFundingAccountSecretARN,
});

new StacksHANodesStack(app, "stacks-ha-nodes", {
    stackName: `stacks-ha-nodes-${config.baseNodeConfig.nodeConfiguration}`,
    env: { account: config.baseConfig.accountId, region: config.baseConfig.region },

    instanceType: config.baseNodeConfig.instanceType,
    instanceCpuType: config.baseNodeConfig.instanceCpuType,
    stacksCluster: config.baseNodeConfig.stacksCluster,
    stacksVersion: config.baseNodeConfig.stacksVersion,
    nodeConfiguration: config.baseNodeConfig.nodeConfiguration,
    dataVolume: config.baseNodeConfig.dataVolume,
    accountsVolume: config.baseNodeConfig.accountsVolume,

    albHealthCheckGracePeriodMin: config.haNodeConfig.albHealthCheckGracePeriodMin,
    heartBeatDelayMin: config.haNodeConfig.heartBeatDelayMin,
    numberOfNodes: config.haNodeConfig.numberOfNodes,
});


// Security Check
cdk.Aspects.of(app).add(
    new nag.AwsSolutionsChecks({
        verbose: false,
        reports: true,
        logIgnores: false,
    })
);
