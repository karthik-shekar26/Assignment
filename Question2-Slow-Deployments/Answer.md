# Slow Deployments

You notice on Github Actions that modio's "deploy-ecs-staging" workflow often takes 25 minutes to deploy a new docker container to the staging ECS cluster, while "normal" deployments take around 8-10 minutes.

Walk us through your troubleshooting approach to find the culprit for the slow, erratic deployments - noting the cloudformation scripts live in a separate repository to the main codebase that is being deployed.

## Systematic Troubleshooting Approach

### 🎯 Step 1: Analyze GitHub Actions Workflow Timeline

**Goal:** Identify which specific step in the deployment pipeline is causing the delay.

**How to Investigate:**
1. Open GitHub Actions → Actions tab → deploy-ecs-staging workflow
2. Compare a slow run (25 min) vs. normal run (8-10 min)
3. Expand each job and note timing per step
4. Pay special attention to:
   - Docker image build and push to ECR
   - ECS service update commands
   - Any `aws ecs wait` or `aws cloudformation deploy` commands

**Tools:**
- GitHub Actions web UI
- Workflow run logs with timestamps
- Runner logs for detailed timing

**Expected Outcome:**
You'll identify which job(s) are introducing delays:
- Docker build: 12 minutes (instead of 4)
- ECS service update: 10-15 minutes for task stabilization
- CloudFormation deployment: unexpected delays

### 🐢 Step 2: Investigate ECS Service Deployment Performance

**Goal:** Understand why ECS service updates are slow and identify resource constraints.

**How to Investigate:**
```bash
# Check service status and deployment state
aws ecs describe-services --cluster staging --services my-service

# Monitor deployment progress
aws ecs describe-deployments --cluster staging --service my-service

# Check task placement and resource availability
aws ecs list-tasks --cluster staging --service-name my-service
```

**Key Areas to Check:**
- Are tasks stuck in `PENDING` state?
- Are new tasks taking long to transition to `RUNNING`?
- Do events show "unable to place task" or "waiting for ENI"?

**Common Issues & Symptoms:**

| Symptom | What It Suggests | Solution |
|---------|------------------|----------|
| Tasks stuck in PENDING | Subnet IP exhaustion, ENI limits (Fargate), ASG scaling delays | Check subnet capacity, increase ENI limits |
| Long RUNNING to STABLE time | Health checks failing or taking long to pass | Optimize health check configuration |
| Image pull taking long | Large images or ECR throttling | Reduce image size, check ECR performance |

**Expected Outcome:** Narrow down whether slowness is caused by ECS resource constraints or health check delays.

### 📦 Step 3: Analyze Docker Image Build & Delivery

**Goal:** Determine if Docker image size or registry performance is contributing to delays.

**How to Investigate:**
```bash
# Check image size and build performance
docker images my-ecr-repo:latest
docker history my-ecr-repo:latest

# Monitor build and push times in workflow logs
docker build -t my-ecr-repo:latest .
docker push my-ecr-repo:latest
```

**Key Metrics to Compare:**
- Image size (target: <200MB, avoid >1GB)
- Build time consistency
- Push/pull latency to ECR
- Layer caching efficiency

**Optimization Strategies:**
- Use multi-stage builds to reduce final image size
- Remove unnecessary dependencies and layers
- Optimize base image selection
- Implement layer caching in CI/CD

**Expected Outcome:** If image is large (>1GB), identify it as a bottleneck and optimize to ~200MB.

### 🏗️ Step 4: Evaluate Health Checks & ECS Task Definition

**Goal:** Ensure health checks aren't delaying ECS deployment stabilization.

**How to Investigate:**
1. **ECS Service Configuration:**
   - Check health check grace period settings
   - Review interval, threshold, and timeout values
   - Verify startup probe configuration

2. **Load Balancer Configuration (if using ALB/NLB):**
   ```bash
   # Check target group settings
   aws elbv2 describe-target-groups --names my-target-group
   aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:...
   ```

**Key Settings to Review:**
- Health check grace period (default: 60s)
- Deregistration delay (default: 300s)
- Health check interval and timeout
- Success/failure thresholds

**Expected Outcome:** If health checks are slow (app takes 60s+ to start), consider:
- Increasing grace period
- Optimizing container startup time
- Implementing mock health endpoints for staging

### 🧱 Step 5: Inspect Infrastructure Dependencies & Cross-Repo Delays

**Goal:** Verify if deployment is blocked by CloudFormation stack updates from the separate repository.

**How to Investigate:**
1. **Check Workflow for Infrastructure Commands:**
   ```bash
   # Look for commands like:
   cd cloudformation && ./deploy.sh
   aws cloudformation deploy --template-file template.yml
   aws cloudformation wait stack-update-complete
   ```

2. **Monitor Stack Update Performance:**
   ```bash
   # Check if stacks are being updated unnecessarily
   aws cloudformation describe-stacks --stack-name my-stack
   aws cloudformation describe-stack-events --stack-name my-stack
   ```

**Potential Issues:**
- Unnecessary stack updates on every deployment
- Drift detection causing delays
- Wait conditions or dependencies
- Cross-stack references taking time

**Expected Outcome:** If infrastructure updates are taking time and aren't necessary for every app deploy, decouple them into separate workflows triggered only on infrastructure changes.

### 🕵️ Step 6: Investigate Container Startup Time

**Goal:** Check if container entrypoint logic is causing startup delays.

**How to Investigate:**
1. **Add Startup Logging:**
   ```dockerfile
   # Add to Dockerfile or entrypoint script
   echo "$(date): Container starting..." >> /var/log/startup.log
   ```

2. **Monitor Startup Process:**
   ```bash
   # Check container logs during startup
   aws logs tail /ecs/my-service --follow
   ```

3. **Test with Minimal Entrypoint:**
   ```bash
   # Override entrypoint in ECS for testing
   Command: ["sleep", "5"]
   ```

**Common Startup Delays:**
- Package installation (`apt install`, `npm install`)
- Database migrations or schema updates
- External service calls (SSM, Secrets Manager)
- Configuration loading from external sources

**Expected Outcome:** If startup time is the issue, optimize the Dockerfile and entrypoint logic to defer non-critical work.

### 📊 Step 7: Leverage CloudWatch Metrics and Logs

**Goal:** Use AWS monitoring tools to visualize task lifecycle and identify resource bottlenecks.

**How to Investigate:**
1. **ECS Metrics Dashboard:**
   - Deployment Duration
   - PendingTaskCount vs RunningTaskCount
   - CPUReservation / MemoryReservation
   - Service CPU/Memory utilization

2. **CloudWatch Logs Analysis:**
   ```bash
   # Monitor ECS agent logs
   aws logs tail /aws/ecs/agent --follow
   
   # Check application logs
   aws logs tail /ecs/my-service --follow
   ```

3. **Set Up Alarms:**
   ```bash
   # Create deployment duration alarm
   aws cloudwatch put-metric-alarm \
     --alarm-name "ECS-Deployment-Duration" \
     --metric-name "DeploymentDuration" \
     --namespace "AWS/ECS" \
     --threshold 600
   ```

**Expected Outcome:** Get visibility into whether this is a resource bottleneck, service misconfiguration, or network issue.

### 🧪 Step 8: Test Hypotheses in Isolation

**Goal:** Validate findings by testing components in isolation.

**How to Investigate:**
1. **Test Minimal ECS Deployment:**
   ```bash
   # Deploy simple nginx image
   aws ecs update-service --cluster staging --service my-service \
     --task-definition nginx:latest
   ```

2. **Test with Dummy Health Check:**
   ```bash
   # Use simple health endpoint
   HealthCheck: {
     "Command": ["CMD-SHELL", "echo 'healthy'"],
     "Interval": 30,
     "Timeout": 5,
     "Retries": 3
   }
   ```

3. **Test Without CloudFormation:**
   - Temporarily remove CloudFormation deployment steps
   - Compare deployment times

**Expected Outcome:** Isolate which component is causing the slowness and validate optimization strategies.

## 🎯 Final Recommendations & Solutions

| Problem Identified | Immediate Solution | Long-term Strategy |
|-------------------|-------------------|-------------------|
| **Large Docker Images** | Optimize Dockerfile with multi-stage builds | Implement image size monitoring and alerts |
| **Health Check Delays** | Increase grace period, optimize startup | Implement health check performance testing |
| **Infrastructure Dependencies** | Decouple CloudFormation from app deployments | Separate infrastructure and application CI/CD pipelines |
| **Task Placement Issues** | Check subnet capacity, increase ENI limits | Implement capacity planning and auto-scaling |
| **Container Startup Slow** | Optimize entrypoint, defer non-critical work | Implement startup time monitoring and optimization |

## 🔍 Most Likely Culprit Analysis

Given that CloudFormation scripts live in a separate repository, the **highest probability cause** is:

**Unnecessary CloudFormation Stack Updates** - The deployment workflow might be triggering infrastructure updates on every application deployment, even when no infrastructure changes are needed. This can add 10-15 minutes to deployment time.

**Secondary Likely Causes:**
1. **ECS Health Check Configuration** - Inappropriate grace periods or health check intervals
2. **Docker Image Size** - Large images causing slow push/pull operations
3. **Resource Constraints** - Insufficient cluster capacity or subnet IP exhaustion

This systematic approach ensures you can quickly identify and resolve the specific bottleneck causing the slow deployments, with clear actionable steps for each potential issue.