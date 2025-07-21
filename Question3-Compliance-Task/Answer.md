# Answer

## Compliance Task: Network ACL Policy Violation Investigation and Remediation

### Executive Summary

Vanta has identified a critical security compliance issue where 153 Network ACLs (NACLs) in mod.io's AWS environment permit inbound access to privileged ports (RDP 3389, SSH 22, etc.). Given that mod.io operates without Windows servers and uses Teleport agents for remote access management, these rules represent unnecessary security risks that require immediate investigation and remediation.

### Initial Assessment and Context

#### 🚨 **Compliance Violation Details**
- **Scope**: 153 Network ACLs across AWS infrastructure
- **Violation Type**: Inbound access to privileged ports (RDP 3389, SSH 22)
- **Risk Level**: High - creates unauthorized access vectors
- **Business Context**: 
  - ❌ No Windows Servers in AWS (RDP 3389 unnecessary)
  - ❌ No OpenSSH usage (SSH 22 unnecessary)
  - ✅ Teleport agents handle all remote access management

#### 🔍 **Investigation Framework**

### Phase 1: Comprehensive Investigation

#### Step 1: **Confirm and Quantify the Violation**

**Primary Method - AWS CLI Analysis:**
```bash
# Retrieve all NACLs with privileged port violations
aws ec2 describe-network-acls --query \
  "NetworkAcls[?Entries[?RuleAction=='allow' && PortRange.From<=22 && PortRange.To>=22 || PortRange.From<=3389 && PortRange.To>=3389]]"

# Expected output: VPC ID, Subnet associations, NACL ID, and offending rule numbers
```

**Secondary Method - Vanta Export:**
- Export detailed findings from Vanta dashboard
- Cross-reference with AWS Config compliance rules
- Validate findings against actual infrastructure

#### Step 2: **Classify and Prioritize NACLs**

**Environment Classification:**
- 🔹 **Production NACLs** (High Priority)
- 🔹 **Staging/Development NACLs** (Medium Priority)  
- 🔹 **Shared Services/NAT NACLs** (Medium Priority)
- 🔹 **Unused/Default NACLs** (Low Priority)

**Subnet Association Analysis:**
```bash
# Map NACLs to subnets and workloads
aws ec2 describe-network-acls --query \
  "NetworkAcls[].{NACLId:NetworkAclId,Subnets:Associations[].SubnetId,VPCId:VpcId}"
```

#### Step 3: **Root Cause Analysis**

**Historical Investigation:**
- Review CloudTrail logs for NACL creation/modification events
- Identify patterns in rule creation (automated deployments, specific teams, time periods)
- Check for legacy configurations from POCs or shared AMIs

**Risk Assessment:**
- Validate no legitimate use cases exist for RDP/SSH rules
- Confirm Teleport agents use custom ports and outbound connections
- Analyze VPC Flow Logs for actual port usage

```bash
# Filter VPC Flow Logs for privileged port activity
filter="dstport = 22 or dstport = 3389 and action = ACCEPT"
```

### Phase 2: Enhanced Detection and Monitoring

#### **AWS Security Hub Integration**

**Role**: Compliance Aggregator + Continuous Monitoring

**Key Benefits:**
- **Centralized Compliance View**: Aggregates findings from AWS Config, GuardDuty, and third-party tools
- **Automated Detection**: Enables AWS Config managed rules for NACL compliance
- **Standardized Format**: Normalizes findings into AWS Security Finding Format (ASFF)
- **Automated Remediation**: Custom actions via Lambda or SSM for rule removal

**Implementation:**
```bash
# Enable Security Hub managed rules for NACL compliance
aws configservice put-config-rule --config-rule file://restricted-ssh-nacl.json

# Common managed rules to enable:
# - vpc-network-acl-allows-unrestricted-ssh
# - vpc-network-acl-allows-unrestricted-rdp
```

#### **Amazon GuardDuty Integration**

**Role**: Threat Detection from Runtime Events

**Key Benefits:**
- **Runtime Threat Detection**: Identifies actual exploitation attempts, not just configuration issues
- **Prioritization**: Helps triage which NACLs are actively being targeted
- **Alerting**: Integrates with CloudWatch Events/EventBridge for automated responses

**Relevant GuardDuty Findings:**
- `Recon:EC2/PortProbeUnprotectedPort` - Detects port scanning on open privileged ports
- `UnauthorizedAccess:EC2/SSHBruteForce` - Identifies SSH brute force attempts
- `Recon:EC2/UnusualPort` - Flags unusual port activity

**Implementation:**
```bash
# Enable GuardDuty if not already active
aws guardduty create-detector --enable
```

### Phase 3: Systematic Remediation Strategy

#### **Preparation Phase (Week 1)**

**Risk Mitigation Setup:**
1. **Backup Current Configurations**: Export all NACL rules and associations
2. **Establish Monitoring**: Enhanced CloudWatch monitoring for affected services
3. **Create Rollback Procedures**: Pre-defined rollback scripts for each environment
4. **Stakeholder Communication**: Notify all teams of planned remediation

**Tool Integration:**
```bash
# Set up Security Hub custom actions for automated remediation
# Configure EventBridge rules for real-time alerting
# Enable VPC Flow Logs for traffic analysis
```

#### **Pilot Remediation (Week 2)**

**Non-Production Testing:**
- Start with 10-15 NACLs in development/staging environments
- Remove RDP (3389) and SSH (22) rules systematically
- Monitor for service disruptions and Teleport connectivity issues
- Validate all legitimate services continue functioning

**Automated Remediation Script:**
```bash
#!/bin/bash
# Example automated NACL rule removal script
for nacl_id in $(aws ec2 describe-network-acls --query "NetworkAcls[].NetworkAclId" --output text); do
    # Remove SSH rule (port 22)
    aws ec2 delete-network-acl-entry \
        --network-acl-id $nacl_id \
        --rule-number 100 \
        --ingress
    
    # Remove RDP rule (port 3389)  
    aws ec2 delete-network-acl-entry \
        --network-acl-id $nacl_id \
        --rule-number 101 \
        --ingress
    
    echo "Removed privileged port rules from NACL: $nacl_id"
done
```

#### **Production Remediation (Weeks 3-4)**

**Batch Processing:**
- Apply lessons learned from pilot phase
- Remediate remaining NACLs in controlled batches
- Maintain detailed change logs and rollback procedures
- Continuous monitoring during each batch

**Validation Process:**
- Functional testing of all services
- Teleport access verification
- Security validation to ensure no unauthorized access vectors remain
- Performance monitoring to detect any network degradation

### Phase 4: Prevention and Compliance

#### **Long-term Prevention Strategies**

**1. Infrastructure as Code (IaC) Controls:**
```yaml
# Example Terraform policy to prevent privileged port rules
resource "aws_network_acl_rule" "example" {
  # Prevent creation of SSH/RDP rules
  lifecycle {
    prevent_destroy = true
  }
  
  # Validation rule
  validate {
    condition = !contains([22, 3389], port)
    error_message = "Privileged ports (22, 3389) are not allowed in NACL rules"
  }
}
```

**2. CI/CD Pipeline Guardrails:**
- Automated scanning of CloudFormation/Terraform templates
- Pre-deployment validation of NACL rules
- Automated rejection of changes allowing privileged ports

**3. AWS Config Rules:**
```json
{
  "ConfigRuleName": "restricted-common-ports",
  "Description": "Evaluates NACLs for insecure open ports",
  "Scope": {
    "ComplianceResourceTypes": ["AWS::EC2::NetworkAcl"]
  },
  "Source": {
    "Owner": "AWS",
    "SourceIdentifier": "RESTRICTED_INCOMING_TRAFFIC"
  }
}
```

**4. Service Control Policies (SCPs):**
- Account-level guardrails to prevent privileged port rules
- Cross-account compliance enforcement
- Automated remediation workflows

#### **Monitoring and Alerting Framework**

**Security Hub Dashboard:**
- Real-time compliance status
- Unresolved findings tracking
- SLA-based resolution monitoring

**GuardDuty Integration:**
- Runtime threat detection
- Automated alerting for suspicious activity
- Integration with incident response workflows

**Custom Alerting:**
```bash
# EventBridge rule for Security Hub findings
aws events put-rule \
  --name "nacl-compliance-alerts" \
  --event-pattern '{"source":["aws.securityhub"],"detail-type":["Security Hub Findings"]}'
```

### Success Metrics and Validation

#### **Quantitative Metrics:**
- ✅ **100% removal** of unnecessary privileged port rules
- ✅ **Zero service disruptions** during remediation
- ✅ **Zero false positives** in Vanta scans post-remediation
- ✅ **100% Security Hub compliance** score

#### **Qualitative Improvements:**
- **Enhanced security posture** with reduced attack surface
- **Improved compliance** with security policies
- **Better operational practices** for NACL management
- **Automated detection** of future violations

### Risk Management

#### **Potential Risks and Mitigations:**

| Risk | Mitigation Strategy |
|------|-------------------|
| Service disruption during remediation | Gradual rollout with comprehensive testing |
| Teleport connectivity issues | Pre-remediation validation and rollback procedures |
| False positive findings | Thorough validation and documentation |
| Recurrence of violations | Automated guardrails and monitoring |

#### **Rollback Procedures:**
```bash
# Emergency rollback script
aws ec2 create-network-acl-entry \
  --network-acl-id $NACL_ID \
  --ingress \
  --rule-number 100 \
  --protocol tcp \
  --port-range From=22,To=22 \
  --cidr-block 0.0.0.0/0
```

### Conclusion

This comprehensive remediation approach leverages both traditional security practices and modern AWS security services to address the Network ACL compliance violation effectively. By combining Vanta's initial detection with Security Hub's centralized compliance management and GuardDuty's runtime threat detection, mod.io can achieve:

1. **Immediate risk reduction** through systematic rule removal
2. **Long-term prevention** via automated guardrails and monitoring
3. **Enhanced visibility** through integrated security tooling
4. **Operational excellence** with improved processes and documentation

The key success factors are thorough preparation, gradual implementation, comprehensive monitoring, and long-term process improvements to prevent recurrence while maintaining operational functionality through Teleport. 