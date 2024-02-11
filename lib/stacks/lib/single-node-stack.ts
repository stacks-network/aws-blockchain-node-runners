import * as cdk from "aws-cdk-lib";
import * as cdkConstructs from "constructs";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as iam from "aws-cdk-lib/aws-iam";
import * as s3Assets from "aws-cdk-lib/aws-s3-assets";
import * as path from "path";
import * as fs from "fs";
import * as nodeCwDashboard from "./assets/node-cw-dashboard"
import * as cw from 'aws-cdk-lib/aws-cloudwatch';
import * as nag from "cdk-nag";
import { SingleNodeConstruct } from "../../constructs/single-node"
import * as configTypes from "./config/stacksConfig.interface";
import * as constants from "../../constructs/constants";
import { StacksNodeSecurityGroupConstruct } from "./constructs/stacks-node-security-group"

export interface StacksSingleNodeStackProps extends cdk.StackProps {
    instanceType: ec2.InstanceType;
    instanceCpuType: ec2.AmazonLinuxCpuType;
    stacksCluster: configTypes.StacksCluster;
    stacksVersion: string;
    nodeConfiguration: configTypes.StacksNodeConfiguration;
    dataVolume: configTypes.StacksDataVolumeConfig;
    accountsVolume: configTypes.StacksAccountsVolumeConfig;
    stacksNodeIdentitySecretARN: string;
    voteAccountSecretARN: string;
    authorizedWithdrawerAccountSecretARN: string;
    registrationTransactionFundingAccountSecretARN: string;
}

export class StacksSingleNodeStack extends cdk.Stack {
    constructor(scope: cdkConstructs.Construct, id: string, props: StacksSingleNodeStackProps) {
        super(scope, id, props);

        // Setting up necessary environment variables
        const REGION = cdk.Stack.of(this).region;
        const STACK_NAME = cdk.Stack.of(this).stackName;
        const STACK_ID = cdk.Stack.of(this).stackId;
        const availabilityZones = cdk.Stack.of(this).availabilityZones;
        const chosenAvailabilityZone = availabilityZones.slice(0, 1)[0];

        // Getting our config from initialization properties
        const {
            instanceType,
            instanceCpuType,
            stacksCluster,
            stacksVersion,
            nodeConfiguration,
            dataVolume,
            accountsVolume,
            stacksNodeIdentitySecretARN,
            voteAccountSecretARN,
            authorizedWithdrawerAccountSecretARN,
            registrationTransactionFundingAccountSecretARN,
        } = props;

        // Using default VPC
        const vpc = ec2.Vpc.fromLookup(this, "vpc", { isDefault: true });

        // Setting up the security group for the node from Stacks-specific construct
        const instanceSG = new StacksNodeSecurityGroupConstruct (this, "security-group", {
            vpc: vpc,
        })

        // Making our scripts and configis from the local "assets" directory available for instance to download
        const asset = new s3Assets.Asset(this, "assets", {
            path: path.join(__dirname, "assets"),
        });

        // Getting the IAM role ARN from the common stack
        const importedInstanceRoleArn = cdk.Fn.importValue("StacksNodeInstanceRoleArn");

        const instanceRole = iam.Role.fromRoleArn(this, "iam-role", importedInstanceRoleArn);

        // Making sure our instance will be able to read the assets
        asset.bucket.grantRead(instanceRole);

        // Setting up the node using generic Single Node constract
        if (instanceCpuType === ec2.AmazonLinuxCpuType.ARM_64) {
            throw new Error("ARM_64 is not yet supported");
        }

        // Use Ubuntu 20.04 LTS image for amd64. Find more: https://discourse.ubuntu.com/t/finding-ubuntu-images-with-the-aws-ssm-parameter-store/15507
        const ubuntu204stableImageSsmName = "/aws/service/canonical/ubuntu/server/20.04/stable/current/amd64/hvm/ebs-gp2/ami-id"

        const node = new SingleNodeConstruct(this, "sync-node", {
            instanceName: STACK_NAME,
            instanceType,
            dataVolumes: [dataVolume, accountsVolume],
            rootDataVolumeDeviceName: "/dev/sda1",
            machineImage: ec2.MachineImage.fromSsmParameter(ubuntu204stableImageSsmName),
            vpc,
            availabilityZone: chosenAvailabilityZone,
            role: instanceRole,
            securityGroup: instanceSG.securityGroup,
            vpcSubnets: {
                subnetType: ec2.SubnetType.PUBLIC,
            },
        });

        // Parsing user data script and injecting necessary variables
        const nodeStartScript = fs.readFileSync(path.join(__dirname, "assets", "user-data", "node.sh")).toString();
        const accountsVolumeSizeBytes = accountsVolume.sizeGiB * constants.GibibytesToBytesConversionCoefficient;
        const dataVolumeSizeBytes = dataVolume.sizeGiB * constants.GibibytesToBytesConversionCoefficient;

        const modifiedInitNodeScript = cdk.Fn.sub(nodeStartScript, {
            _AWS_REGION_: REGION,
            _ASSETS_S3_PATH_: `s3://${asset.s3BucketName}/${asset.s3ObjectKey}`,
            _STACK_NAME_: STACK_NAME,
            _STACK_ID_: STACK_ID,
            _NODE_CF_LOGICAL_ID_: node.nodeCFLogicalId,
            _ACCOUNTS_VOLUME_TYPE_: accountsVolume.type,
            _ACCOUNTS_VOLUME_SIZE_: accountsVolumeSizeBytes.toString(),
            _DATA_VOLUME_TYPE_: dataVolume.type,
            _DATA_VOLUME_SIZE_: dataVolumeSizeBytes.toString(),
            _STACKS_VERSION_: stacksVersion,
            _STACKS_NODE_TYPE_: nodeConfiguration,
            _NODE_IDENTITY_SECRET_ARN_: stacksNodeIdentitySecretARN,
            _VOTE_ACCOUNT_SECRET_ARN_: voteAccountSecretARN,
            _AUTHORIZED_WITHDRAWER_ACCOUNT_SECRET_ARN_: authorizedWithdrawerAccountSecretARN,
            _REGISTRATION_TRANSACTION_FUNDING_ACCOUNT_SECRET_ARN_: registrationTransactionFundingAccountSecretARN,
            _STACKS_CLUSTER_: stacksCluster,
            _LIFECYCLE_HOOK_NAME_: constants.NoneValue,
            _ASG_NAME_: constants.NoneValue,
        });
        node.instance.addUserData(modifiedInitNodeScript);

        // Adding CloudWatch dashboard to the node
        const dashboardString = cdk.Fn.sub(JSON.stringify(nodeCwDashboard.SingleNodeCWDashboardJSON), {
            INSTANCE_ID:node.instanceId,
            INSTANCE_NAME: STACK_NAME,
            REGION: REGION,
        })

        new cw.CfnDashboard(this, 'stacks-cw-dashboard', {
            dashboardName: `${STACK_NAME}-${node.instanceId}`,
            dashboardBody: dashboardString,
        });

        new cdk.CfnOutput(this, "node-instance-id", {
            value: node.instanceId,
        });

        // Adding suppressions to the stack
        nag.NagSuppressions.addResourceSuppressions(
            this,
            [
                {
                    id: "AwsSolutions-IAM5",
                    reason: "Need read access to the S3 bucket with assets",
                },
            ],
            true
        );
    }
}
