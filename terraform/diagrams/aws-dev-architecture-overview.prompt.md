# AWS Dev Architecture Overview Image Prompt

This image was generated with the built-in `imagegen` tool. Terraform and Ansible remain the source of truth; this prompt only describes the README overview image.

## Reference Images

- `../../../workspaces/assets/dropmong-system-architecture-sheet.png`: monochrome component and line-style reference
- `../../../workspaces/assets/dropmong-system-architecture-sheet-color.png`: semantic-color reference

## Generation Prompt

```text
Use case: infographic-diagram
Asset type: repository README infrastructure architecture diagram
Primary request: Create one polished landscape architecture diagram for the current DropMong AWS development infrastructure. This is a new diagram; the two inputs are style references only, not edit targets.
Input images: Image 1 is the monochrome DropMong architecture component-sheet style reference. Image 2 is the semantic-color variant. Inherit their rounded modular cards, clean 2 px outline icons, dashed group boundaries, thin orthogonal connectors, generous white space, compact labels, and calm engineering-document tone. Do not copy the component catalog layout or reproduce a logo.
Scene/backdrop: soft white to very pale lavender technical canvas with subtle modular panels, no dark background.
Composition/framing: landscape. Clear top-to-bottom hierarchy: delivery and management band at top; shared AWS resources below it; one large AWS region/VPC container in the center; three equal availability-zone columns inside; Internet Gateway and legend at bottom. Make the topology readable at README width.
Title (verbatim): "DROPMONG · AWS DEV INFRASTRUCTURE"
Subtitle (verbatim): "ap-northeast-2 · SELF-MANAGED KUBERNETES · TERRAFORM + ANSIBLE"

Top band label (verbatim): "DELIVERY & MANAGEMENT"
Top band must show this accurate sequence with simple generic line icons and labeled connectors:
"Platform Operator" -> "GitHub Actions" -> "OIDC Deploy Role" -> "Terraform + Ansible"
Also show "SSM" as the operator and Ansible management path into the Kubernetes nodes.
Shared resource cards (verbatim): "S3 REMOTE STATE" and "SHARED ECR". Terraform connects to S3 state and provisions ECR/VPC resources. ECR connects to the Kubernetes worker pool for image pulls.

Main container labels (verbatim):
"AWS · ap-northeast-2"
"DEV VPC · 10.20.0.0/16 · PUBLIC SUBNETS ONLY · NO NAT / NO NLB"
Inside, draw one dashed purple boundary labeled "SELF-MANAGED KUBERNETES · 1 CONTROL PLANE + 6 WORKERS" spanning all three AZ columns.

AZ column 1 labels (verbatim):
"AZ A · ap-northeast-2a"
"PUBLIC SUBNET · 10.20.10.0/24"
Three node cards, each exactly once:
"CONTROL PLANE" / "t4g.medium · gp3 20 GiB"
"PLATFORM WORKER" / "t4g.large · gp3 20 GiB"
"OBSERVABILITY" / "r6g.medium · gp3 20 GiB"

AZ column 2 labels (verbatim):
"AZ B · ap-northeast-2b"
"PUBLIC SUBNET · 10.20.20.0/24"
Two node cards, each exactly once:
"APP WORKER 1" / "t4g.medium · gp3 20 GiB"
"DATA WORKER 1" / "t4g.medium · gp3 20 GiB"

AZ column 3 labels (verbatim):
"AZ C · ap-northeast-2c"
"PUBLIC SUBNET · 10.20.30.0/24"
Two node cards, each exactly once:
"APP WORKER 2" / "t4g.medium · gp3 20 GiB"
"DATA WORKER 2" / "t4g.medium · gp3 20 GiB"

Bottom card (verbatim): "INTERNET GATEWAY · OUTBOUND + PUBLIC IPv4"
Add a small badge (verbatim): "7 ARM64 NODES · ENCRYPTED gp3 · 20 GiB EACH"
Legend (verbatim): "MANAGEMENT", "ARTIFACT", "NETWORK"; solid arrow for management, dashed arrow for artifact, dotted green line for network.

Style/medium: high-fidelity vector-like technical infographic rendered as a raster PNG; crisp sans-serif typography; minimal outlined icons from the visual language of the references; rounded cards; subtle soft fills.
Color palette: primary purple #6C3DF5 and #8869FF for infrastructure and compute; green #22C55E for network; blue #3882F6 for data workers and storage; lavender for observability; navy #111827 for text; pale gray borders.
Constraints: preserve the exact topology and node allocation. Every label must be legible and rendered verbatim. Keep labels horizontal. One node per card. Exactly seven EC2 node cards total. The Kubernetes boundary must span all seven nodes while each subnet remains visibly separate. Show the SSM management path to the private Kubernetes API/control plane without implying a publicly exposed API.
Avoid: no EKS, no managed Kubernetes, no NAT Gateway, no NLB or ALB, no RDS, no database product icons, no Kafka, no application microservices, no extra nodes, no fourth AZ, no duplicate node, no official DropMong logo recreation, no AWS architecture-diagram visual style, no photorealism, no 3D, no decorative illustration, no tiny footnotes, no watermark.
```

## Connector Correction Prompt

```text
Use case: precise-object-edit
Asset type: repository README infrastructure architecture diagram
Primary request: Correct only the connector topology. Preserve the entire layout, canvas, cards, colors, typography, icons, title, subtitle, wording, node allocation, sizes, and visual style unchanged.

Required connector corrections:
1. Keep "Platform Operator" -> "GitHub Actions" -> "OIDC Deploy Role" -> "Terraform + Ansible" as the delivery sequence.
2. Remove any connector from "OIDC Deploy Role" to "S3 REMOTE STATE". Draw a connector from "Terraform + Ansible" to "S3 REMOTE STATE" labeled "STATE". The deploy role must connect only to Terraform + Ansible.
3. Keep a provisioning connector from "Terraform + Ansible" to the AWS/VPC container labeled "PROVISIONS".
4. Keep "SHARED ECR" connected from "Terraform + Ansible" and draw one dashed artifact connector from "SHARED ECR" to the outer "SELF-MANAGED KUBERNETES" boundary labeled "IMAGE PULLS". It must terminate at the cluster boundary, not one individual worker.
5. Draw one solid management connector from the "SSM" card to the outer "SELF-MANAGED KUBERNETES" boundary labeled "NODE SESSIONS" and mark the control-plane path "API TUNNEL". Do not imply public API exposure.
6. Remove unexplained arrows entering individual nodes.
7. Draw a dotted green network bus from "INTERNET GATEWAY · OUTBOUND + PUBLIC IPv4" upward, branching once to each of the three availability-zone public subnet containers. Connect to subnet containers, not individual nodes.
8. Keep the legend semantics: solid purple = MANAGEMENT, dashed purple = ARTIFACT, dotted green = NETWORK.

Constraints: change connectors and their small connector labels only. Preserve all exact labels already rendered correctly. Preserve exactly seven node cards and all three subnet CIDRs. No new services, cards, icons, nodes, arrows, or decoration beyond the corrected connectors. No watermark.
```
