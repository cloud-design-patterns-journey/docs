# Injecting secrets into Kubernetes pods via Vault Agent

~30 min

Deploying applications that act as secret consumers of Vault require the application to:

*   Authenticate and acquire a client token.
*   Manage the lifecycle of the token.
*   Retrieve secrets from Vault.
*   Manage the leases of any dynamic secrets.

Vault Agent takes responsibility for these tasks and enables your applications to remain unaware of Vault. However, this introduces a new requirement that deployments install and configure Vault Agent alongside the application as a sidecar.

The Vault Helm chart enables you to run Vault and the Vault [Agent Sidecar Injector service](https://developer.hashicorp.com/vault/docs/platform/k8s/injector). This injector service leverages the [Sidecar container pattern](https://medium.com/bb-tutorials-and-thoughts/kubernetes-learn-sidecar-container-pattern-6d8c21f873d) and Kubernetes [mutating admission webhook](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#mutatingadmissionwebhook) to intercept pods that define specific annotations and inject a Vault Agent container to manage these secrets.

This is beneficial because:

*   Applications remain Vault unaware as the secrets are stored on the file-system in their container.
*   Existing deployments require no change; as annotations can be patched.
*   Access to secrets can be enforced via Kubernetes service accounts and namespaces

In this tutorial, you setup Vault and this injector service with the Vault Helm chart. Then you will deploy several applications to demonstrate how this new injector service retrieves and writes these secrets for the applications to use.

This tutorial requires:

*   [Docker](https://www.docker.com/products/docker-desktop/)
*   [Kubernetes command-line interface (CLI)](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
    *   **Note**: if running on OpenShift, `oc` CLI can be used, it can be installed through the help section of your OpenShift console.
*   [Helm CLI](https://helm.sh/docs/intro/install/)
*   Kubernetes/OpenShift cluster accessible.
    *   **Note**: you can run this lab locally using [Minikube](https://minikube.sigs.k8s.io/docs/start).

#### [](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#install-kubectl-and-helm-clis)Install kubectl and helm CLIs

Install `kubectl` with [Homebrew](https://brew.sh/) (Linux/Macos).

    $ brew install kubernetes-cli
    
Install `helm` with Homebrew.

This tutorial was last tested 21 May 2023 on a macOS 13.3.1 using the following software versions.

    $ docker version
    Client:
    Cloud integration: v1.0.25
    Version:           20.10.16
    ## ...
    

    $ helm version
    version.BuildInfo{Version:"v3.12.0", GitCommit:"c9f554d75773799f72ceef38c51210f1842a1dea", GitTreeState:"clean", GoVersion:"go1.20.4"}
    

    $ kubectl version --short
    Client Version: v1.27.1
    Kustomize Version: v5.0.1
    Server Version: v1.26.3
    
1.  Retrieve the web application and additional configuration by cloning the [hashicorp-education/learn-vault-kubernetes-sidecar](https://github.com/hashicorp-education/learn-vault-kubernetes-sidecar) repository from GitHub.
    
        $ git clone https://github.com/hashicorp-education/learn-vault-kubernetes-sidecar.git
        
    
2.  Move into the clones repository.
    
        $ cd learn-vault-kubernetes-sidecar
            
    This tutorial assumes that the following commands are executed in this directory.

The recommended way to run Vault on Kubernetes is via the [Helm chart](https://developer.hashicorp.com/vault/docs/platform/k8s/helm). [Helm](https://helm.sh/docs/helm/) is a package manager that installs and configures all the necessary components to run Vault in several different modes. A Helm chart includes [templates](https://helm.sh/docs/chart_template_guide) that enable conditional and parameterized execution. These parameters can be set through command-line arguments or defined in YAML.

1.  Add the HashiCorp Helm repository.

    ```sh
    $ helm repo add hashicorp https://helm.releases.hashicorp.com
    "hashicorp" has been added to your repositories
    ```
        
    
2.  Update all the repositories to ensure `helm` is aware of the latest versions.
    
    ```sh
    $ helm repo update
    Hang tight while we grab the latest from your chart repositories...
    ...Successfully got an update from the "hashicorp" chart repository
    Update Complete. ⎈Happy Helming!⎈
    ```
        
    
3.  *Optional*: if running on OpenShift, create a `vault-ocp.values.yaml` file with required configuration for OpenShift (security context constraints):

    ```yaml
    cat <<EOF > vault-ocp.values.yaml
    global:
       openshift: true

    injector:
       image:
          repository: "registry.connect.redhat.com/hashicorp/vault-k8s"
          tag: "1.4.1-ubi"

    agentImage:
       repository: "registry.connect.redhat.com/hashicorp/vault"
       tag: "1.16.1-ubi"

    server:
       image:
          repository: "registry.connect.redhat.com/hashicorp/vault"
          tag: "1.16.1-ubi"

    readinessProbe:
       path: "/v1/sys/health?uninitcode=204"
    EOF
    ```

4.  Create a new `lab-security-${INITIALS}` namespace (suffixed with your initials):
    ```sh
    $ export INITIALS=ns # CHANGEME
    $ kubectl create namespace lab-security-${INITIALS}
    $ kubectl config set-context --current --namespace lab-security-${INITIALS}
    ```
5.  Install the latest version of the Vault server running in development mode. If running on OpenShift add `-f vault-ocp.values.yaml` to use additional configuration:
    
        $ helm install vault hashicorp/vault --set "server.dev.enabled=true" [-f vault-ocp.values.yaml]
        NAME: vault
        ## ...
    
    The Vault pod and Vault Agent Injector pod are deployed in the `lab-security-${INITIALS}` namespace.
    
6.  Display all the pods in the `lab-security-${INITIALS}` namespace.
    
    ```sh
    $ kubectl get pods
    NAME                                    READY   STATUS    RESTARTS   AGE
    vault-0                                 1/1     Running   0          80s
    vault-agent-injector-5945fb98b5-tpglz   1/1     Running   0          80s
    ```
        
    The `vault-0` pod runs a Vault server in development mode. The `vault-agent-injector` pod performs the injection based on the annotations present or patched on a deployment.
    
    Development mode
    
    Running a Vault server in development is automatically initialized and unsealed. This is ideal in a learning environment but NOT recommended for a production environment.
    
    Wait until the `vault-0` pod and `vault-agent-injector` pod are running and ready (`1/1`).
    

The applications that you deploy in the [Inject secrets into the pod](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#inject-secrets-into-the-pod) section expect Vault to store a username and password stored at the path `internal/database/config`. To create this secret requires that a [key-value secret engine](https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2) is enabled and a username and password is put at the specified path.

1.  Start an interactive shell session on the `vault-0` pod.
    
        $ kubectl exec -it vault-0 -- /bin/sh
        / $
        
    
    Your system prompt is replaced with a new prompt `/ $`. Commands issued at this prompt are executed on the `vault-0` container.
    
2.  Enable kv-v2 secrets at the path `internal`.
    
        $ vault secrets enable -path=internal kv-v2
        Success! Enabled the kv-v2 secrets engine at: internal/
        
    
    Learn more
    
    This tutorial focuses on Vault's integration with Kubernetes and not interacting the key-value secrets engine. For more information refer to the [Static Secrets: Key/Value Secret](https://developer.hashicorp.com/vault/tutorials/secrets-management/static-secrets) tutorial.
    
3.  Create a secret at path `internal/database/config` with a `username` and `password`.
    
        $ vault kv put internal/database/config username="db-readonly-username" password="db-secret-password"
        Key              Value
        ---              -----
        created_time     2020-03-25T19:03:57.127711644Z
        deletion_time    n/a
        destroyed        false
        version          1
        
    
4.  Verify that the secret is defined at the path `internal/database/config`.
    
        $ vault kv get internal/database/config
        ====== Metadata ======
        Key              Value
        ---              -----
        created_time     2020-03-25T19:03:57.127711644Z
        deletion_time    n/a
        destroyed        false
        version          1
        
        ====== Data ======
        Key         Value
        ---         -----
        password    db-secret-password
        username    db-readonly-username
        
    
    The secret is ready for the application.
    
5.  Lastly, exit the `vault-0` pod.
    

Vault provides a [Kubernetes authentication](https://developer.hashicorp.com/vault/docs/auth/kubernetes) method that enables clients to authenticate with a Kubernetes Service Account Token. This token is provided to each pod when it is created.

1.  Start an interactive shell session on the `vault-0` pod.
    
        $ kubectl exec -it vault-0 -- /bin/sh
        / $
        
    
    Your system prompt is replaced with a new prompt `/ $`. Commands issued at this prompt are executed on the `vault-0` container.
    
2.  Enable the Kubernetes authentication method.
    
        $ vault auth enable kubernetes
        Success! Enabled kubernetes auth method at: kubernetes/
        
    
    Vault accepts a service token from any client in the Kubernetes cluster. During authentication, Vault verifies that the service account token is valid by querying a token review Kubernetes endpoint.
    
3.  Configure the Kubernetes authentication method to use the location of the Kubernetes API.
    
    Note
    
    For the best compatibility with recent Kubernetes versions, ensure you are using Vault v1.13.3 or greater.

        $ JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
        $ KUBERNETES_HOST=https://${KUBERNETES_PORT_443_TCP_ADDR}:443
        $ vault write --tls-skip-verify auth/kubernetes/config \
        token_reviewer_jwt=$JWT kubernetes_host=$KUBERNETES_HOST \
        kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    
    Successful output from the command resembles this example:
    
        Success! Data written to: auth/kubernetes/config
        
    
    The environment variable `KUBERNETES_PORT_443_TCP_ADDR` is defined and references the internal network address of the Kubernetes host.
    
    For a client to read the secret data defined at `internal/database/config`, requires that the read capability be granted for the path `internal/data/database/config`. This is an example of a [policy](https://developer.hashicorp.com/vault/docs/concepts/policies). A policy defines a set of capabilities.
    
4.  Write out the policy named `internal-app` that enables the `read` capability for secrets at path `internal/data/database/config`.
    
        $ vault policy write internal-app - <<EOF
        path "internal/data/database/config" {
           capabilities = ["read"]
        }
        EOF
        
    
5.  Create a Kubernetes authentication role named `internal-app`.
    
    ```sh
    $ export INITIALS=ns # changeme
    $ vault write auth/kubernetes/role/internal-app \
            bound_service_account_names=internal-app \
            bound_service_account_namespaces=lab-security-${INITIALS} \
            policies=internal-app \
            ttl=24h
    ```
    
    Successful output from the command resembles this example:
    
        Success! Data written to: auth/kubernetes/role/internal-app
        
    
    The role connects the Kubernetes service account, `internal-app`, and namespace, `lab-security-${INITIALS}`, with the Vault policy, `internal-app`. The tokens returned after authentication are valid for 24 hours.
    
6.  Lastly, exit the `vault-0` pod.
    

The Vault Kubernetes authentication role defined a Kubernetes service account named `internal-app`.

A service account provides an identity for processes that run in a Pod. With this identity we will be able to run the application within the cluster.

1.  Get all the service accounts in the lab-security-${INITIALS} namespace.
    
        $ kubectl get serviceaccounts
        NAME                   SECRETS   AGE
        lab-security-ns                1         43m
        vault                  1         34m
        vault-agent-injector   1         34m
        
    
2.  Create a Kubernetes service account named `internal-app` in the `lab-security-${INITIALS}` namespace.
    
        $ kubectl create sa internal-app
        
    
3.  Verify that the service account has been created.
    
        $ kubectl get serviceaccounts
        NAME                   SECRETS   AGE
        lab-security-ns        1         52m
        internal-app           1         13s
        vault                  1         43m
        vault-agent-injector   1         43m
        
    
    The name of the service account here aligns with the name assigned to the `bound_service_account_names` field when the `internal-app` role was created.
    

You have created a sample application, published it to DockerHub, and created a Kubernetes deployment that launches this application.

1.  Display the deployment for the `orgchart` application.
    
        $ cat deployment-orgchart.yaml
        
    
        apiVersion: apps/v1
        kind: Deployment
        metadata:
           name: orgchart
           labels:
              app: orgchart
        spec:
           selector:
              matchLabels:
              app: orgchart
           replicas: 1
           template:
              metadata:
              annotations:
              labels:
                 app: orgchart
              spec:
              serviceAccountName: internal-app
              containers:
                 - name: orgchart
                    image: jweissig/app:0.0.1
        
    
    The name of this deployment is `orgchart`. The `spec.template.spec.serviceAccountName` defines the service account `internal-app` to run this container.
    
2.  Apply the deployment defined in `deployment-orgchart.yaml`.
    
        $ kubectl apply --filename deployment-orgchart.yaml
        deployment.apps/orgchart created
        
    
3.  Get all the pods in the `lab-security-${INITIALS}` namespace and note down the name of the pod with a name prefixed with "orgchart-".
    
        $ kubectl get pods
        NAME                                    READY   STATUS    RESTARTS   AGE
        orgchart-69697d9598-l878s               1/1     Running   0          18s
        vault-0                                 1/1     Running   0          58m
        vault-agent-injector-5945fb98b5-tpglz   1/1     Running   0          58m
        
    
    The orgchart pod is displayed here as the pod prefixed with `orgchart`.
    
    Additional waiting
    
    The deployment of the pod requires the retrieval of the application container from [Docker Hub](https://hub.docker.com/). This displays the STATUS of `ContainerCreating`. The pod reports that it is not ready (`0/1`).
    
    The Vault-Agent injector looks for deployments that define specific annotations. None of these annotations exist in the current deployment. This means that no secrets are present on the `orgchart` container in the `orgchart` pod.
    
    Note
    
    Consider removing the rest of this section - the user should not purposely fail...
    
4.  Verify that no secrets are written to the `orgchart` container in the `orgchart` pod.
    
        $ kubectl exec \
              $(kubectl get pod -l app=orgchart -o jsonpath="{.items[0].metadata.name}") \
              --container orgchart -- ls /vault/secrets
        
    
    The output displays that there is no such file or directory named `/vault/secrets`:
    
        ls: /vault/secrets: No such file or directory
        command terminated with exit code 1
        
    

The deployment is running the pod with the `internal-app` Kubernetes service account in the `lab-security-${INITIALS}` namespace. The Vault Agent Injector only modifies a deployment if it contains a specific set of annotations. An existing deployment may have its definition patched to include the necessary annotations.

1.  Display the deployment patch `patch-inject-secrets.yaml`.
    
        $ cat patch-inject-secrets.yaml
        
    
    patch-inject-secrets.yaml
    
        spec:
           template:
              metadata:
              annotations:
                 vault.hashicorp.com/agent-inject: 'true'
                 vault.hashicorp.com/role: 'internal-app'
                 vault.hashicorp.com/agent-inject-secret-database-config.txt: 'internal/data/database/config'
        
    
    These [annotations](https://developer.hashicorp.com/vault/docs/platform/k8s/injector/annotations) define a partial structure of the deployment schema and are prefixed with `vault.hashicorp.com`.
    
    *   [`agent-inject`](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#agent-inject) enables the Vault Agent Injector service
    *   [`role`](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#role) is the Vault Kubernetes authentication role
    *   [`agent-inject-secret-FILEPATH`](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#agent-inject-secret-filepath) prefixes the path of the file, `database-config.txt` written to the `/vault/secrets` directory. The value is the path to the secret defined in Vault.
2.  Patch the `orgchart` deployment defined in `patch-inject-secrets.yaml`.
    
        $ kubectl patch deployment orgchart --patch "$(cat patch-inject-secrets.yaml)"
        deployment.apps/orgchart patched
        
    
    A new `orgchart` pod starts alongside the existing pod. When it is ready the original terminates and removes itself from the list of active pods.
    
3.  Get all the pods in the `lab-security-${INITIALS}` namespace.
    
        $ kubectl get pods
        NAME                                    READY   STATUS     RESTARTS   AGE
        orgchart-599cb74d9c-s8hhm               0/2     Init:0/1   0          23s
        orgchart-69697d9598-l878s               1/1     Running    0          20m
        vault-0                                 1/1     Running    0          78m
        vault-agent-injector-5945fb98b5-tpglz   1/1     Running    0          78m
        
    
    Wait until the re-deployed `orgchart` pod reports that it is [`Running`](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-phase) and ready (`2/2`).
    
    This new pod now launches two containers. The application container, named `orgchart`, and the Vault Agent container, named `vault-agent`.
    
4.  Display the logs of the `vault-agent` container in the new `orgchart` pod.
    
        $ kubectl logs \
              $(kubectl get pod -l app=orgchart -o jsonpath="{.items[0].metadata.name}") \
              --container vault-agent
        
    
    Vault Agent manages the token lifecycle and the secret retrieval. The secret is rendered in the `orgchart` container at the path `/vault/secrets/database-config.txt`.
    
5.  Display the secret written to the `orgchart` container.
    
        $ kubectl exec \
              $(kubectl get pod -l app=orgchart -o jsonpath="{.items[0].metadata.name}") \
              --container orgchart -- cat /vault/secrets/database-config.txt
        
    
    The unformatted secret data is present on the container:
    
        data: map[password:db-secret-password username:db-readonly-user]
        metadata: map[created_time:2019-12-20T18:17:50.930264759Z deletion_time: destroyed:false version:2]
        
    

The structure of the injected secrets may need to be structured in a way for an application to use. Before writing the secrets to the file system a template can structure the data. To apply this template a new set of annotations need to be applied.

1.  Display the annotations file that contains a template definition.
    
        $ cat patch-inject-secrets-as-template.yaml
        
    
    patch-inject-secrets-as-template.yaml
    
        spec:
           template:
              metadata:
              annotations:
                 vault.hashicorp.com/agent-inject: 'true'
                 vault.hashicorp.com/agent-inject-status: 'update'
                 vault.hashicorp.com/role: 'internal-app'
                 vault.hashicorp.com/agent-inject-secret-database-config.txt: 'internal/data/database/config'
                 vault.hashicorp.com/agent-inject-template-database-config.txt: |
                    {{- with secret "internal/data/database/config" -}}
                    postgresql://{{ .Data.data.username }}:{{ .Data.data.password }}@postgres:5432/wizard
                    {{- end -}}
        
    
    This patch contains two new annotations:
    
    *   [`agent-inject-status`](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#agent-inject-status) set to `update` informs the injector reinject these values.
    *   [`agent-inject-template-FILEPATH`](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#agent-inject-template-filepath) prefixes the file path. The value defines the [Vault Agent template](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent/template) to apply to the secret's data.
    
    The template formats the username and password as a PostgreSQL connection string.
    
2.  Apply the updated annotations.
    
        $ kubectl patch deployment orgchart --patch "$(cat patch-inject-secrets-as-template.yaml)"
        deployment.apps/exampleapp patched
        
    
3.  Get all the pods in the `lab-security-${INITIALS}` namespace.
    
        $ kubectl get pods
        NAME                                    READY   STATUS    RESTARTS   AGE
        orgchart-554db4579d-w6565               2/2     Running   0          16s
        vault-0                                 1/1     Running   0          126m
        vault-agent-injector-5945fb98b5-tpglz   1/1     Running   0          126m
        
    
    Wait until the re-deployed `orgchart` pod reports that it is [`Running`](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-phase) and ready (`2/2`).
    
4.  Finally, display the secret written to the `orgchart` container in the `orgchart` pod.
    
        $ kubectl exec \
              $(kubectl get pod -l app=orgchart -o jsonpath="{.items[0].metadata.name}") \
              -c orgchart -- cat /vault/secrets/database-config.txt
        
    
    The secrets are rendered in a PostgreSQL connection string is present on the container:
    
        postgresql://db-readonly-user:db-secret-password@postgres:5432/wizard
        
    

The annotations may patch these secrets into any deployment. Pods require that the annotations be included in their initial definition.

1.  Display the pod definition for the `payroll` application.
    
        apiVersion: v1
        kind: Pod
        metadata:
        name: payroll
        labels:
           app: payroll
        annotations:
           vault.hashicorp.com/agent-inject: 'true'
           vault.hashicorp.com/role: 'internal-app'
           vault.hashicorp.com/agent-inject-secret-database-config.txt: 'internal/data/database/config'
           vault.hashicorp.com/agent-inject-template-database-config.txt: |
              {{- with secret "internal/data/database/config" -}}
              postgresql://{{ .Data.data.username }}:{{ .Data.data.password }}@postgres:5432/wizard
              {{- end -}}
        spec:
        serviceAccountName: internal-app
        containers:
           - name: payroll
              image: jweissig/app:0.0.1
        
    
2.  Apply the pod defined in `pod-payroll.yaml`.
    
        $ kubectl apply --filename pod-payroll.yaml
        pod/payroll created
        
    
3.  Get all the pods in the `lab-security-${INITIALS}` namespace.
    
        $ kubectl get pods
        NAME                                    READY   STATUS    RESTARTS   AGE
        orgchart-554db4579d-w6565               2/2     Running   0          29m
        payroll                                 2/2     Running   0          12s
        vault-0                                 1/1     Running   0          155m
        vault-agent-injector-5945fb98b5-tpglz   1/1     Running   0          155m
        
    
    Wait until the `payroll` pod reports that it is [`Running`](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-phase) and ready (`2/2`).
    
4.  Display the secret written to the `payroll` container in the `payroll` pod.
    
        $ kubectl exec \
              payroll \
              --container payroll -- cat /vault/secrets/database-config.txt
        
    
    The secrets are rendered in a PostgreSQL connection string is present on the container:
    
        postgresql://db-readonly-user:db-secret-password@postgres:5432/wizard
        
    

Pods run with a Kubernetes service account other than the ones defined in the Vault Kubernetes authentication role are **NOT** able to access the secrets defined at that path.

1.  Display the deployment and service account for the `website` application.
    
        $ cat deployment-website.yaml
        
    
        apiVersion: apps/v1
        kind: Deployment
        metadata:
        name: website
        labels:
           app: website
        spec:
        selector:
           matchLabels:
              app: website
        replicas: 1
        template:
           metadata:
              annotations:
              vault.hashicorp.com/agent-inject: 'true'
              vault.hashicorp.com/role: 'internal-app'
              vault.hashicorp.com/agent-inject-secret-database-config.txt: 'internal/data/database/config'
              vault.hashicorp.com/agent-inject-template-database-config.txt: |
                 {{- with secret "internal/data/database/config" -}}
                 postgresql://{{ .Data.data.username }}:{{ .Data.data.password }}@postgres:5432/wizard
                 {{- end -}}
              labels:
              app: website
           spec:
              # This service account does not have permission to request the secrets.
              serviceAccountName: website
              containers:
              - name: website
                 image: jweissig/app:0.0.1
        ---
        apiVersion: v1
        kind: ServiceAccount
        metadata:
        name: website
        
    
2.  Apply the deployment and service account defined in `deployment-website.yaml`.
    
        $ kubectl apply --filename deployment-website.yaml
        deployment.apps/website created
        serviceaccount/website created
        
    
3.  Get all the pods in the `lab-security-${INITIALS}` namespace.
    
        $ kubectl get pods
        NAME                                    READY   STATUS     RESTARTS   AGE
        orgchart-554db4579d-w6565               2/2     Running    0          29m
        payroll                                 2/2     Running    0          12s
        vault-0                                 1/1     Running    0          155m
        vault-agent-injector-5945fb98b5-tpglz   1/1     Running    0          155m
        website-7fc8b69645-527rf                0/2     Init:0/1   0          76s
        
    
    The `website` deployment creates a pod but it is **NEVER** ready.
    
4.  Display the logs of the `vault-agent-init` container in the `website` pod.
    
        $ kubectl logs \
              $(kubectl get pod -l app=website -o jsonpath="{.items[0].metadata.name}") \
              --container vault-agent-init
        
    
    The initialization process failed because the service account name is not authorized:
    
        ...
        [INFO]  auth.handler: authenticating
        [ERROR] auth.handler: error authenticating: error="Error making API request.
        
        URL: PUT http://vault.lab-security-ns.svc:8200/v1/auth/kubernetes/login
        Code: 500. Errors:
        
        * service account name not authorized" backoff=1.562132589
        
    
    The service account, `external-app` is not assigned to any Vault Kubernetes authentication role. This failure to authenticate causes the deployment to fail initialization.
    
5.  Display the deployment patch `patch-website.yaml`.
    
        spec:
           template:
              spec:
              serviceAccountName: internal-app
        
    
    The patch modifies the deployment definition to use the service account `internal-app`. This Kubernetes service account is authorized by the Vault Kubernetes authentication role.
    
6.  Patch the `website` deployment defined in `patch-website.yaml`.
    
        $ kubectl patch deployment website --patch "$(cat patch-website.yaml)"
        
    
7.  Get all the pods in the `lab-security-${INITIALS}` namespace.
    
        $ kubectl get pods
        NAME                                    READY   STATUS     RESTARTS   AGE
        orgchart-554db4579d-w6565               2/2     Running    0          29m
        payroll                                 2/2     Running    0          12s
        vault-0                                 1/1     Running    0          155m
        vault-agent-injector-5945fb98b5-tpglz   1/1     Running    0          155m
        website-788d689b87-tll2r                2/2     Running    0          27s
        
    
    Wait until the `website` pod reports that it is [`Running`](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-phase) and ready (`2/2`).
    
8.  Finally, display the secret written to the `website` container in the `website` pod.
    
        $ kubectl exec \
              $(kubectl get pod -l app=website -o jsonpath="{.items[0].metadata.name}") \
              --container website -- cat /vault/secrets/database-config.txt
        
    
    The secrets are rendered in a PostgreSQL connection string is present on the container:
    
        postgresql://db-readonly-user:db-secret-password@postgres:5432/wizard
            
    Alternatively, you can define a new Vault Kubernetes role, that enables the original service account access, and patch the deployment.
    

Pods run in a namespace other than the ones defined in the Vault Kubernetes authentication role are **NOT** able to access the secrets defined at that path.

1.  Create the `lab-security-offsite-${INITIALS}` namespace.
    
        $ kubectl create namespace lab-security-offsite-${INITIALS}
        namespace/lab-security-offsite-ns created
        
    
2.  Set the current context to the `lab-security-offsite-${INITIALS}` namespace.
    
        $ kubectl config set-context --current --namespace lab-security-offsite-${INITIALS}
        Context "..." modified.
        
    
3.  Create a Kubernetes service account named `internal-app` in the `lab-security-offsite-${INITIALS}` namespace.
    
        $ kubectl create sa internal-app
        serviceaccount/internal-app created
        
    
4.  Display the deployment for the `issues` application.
    
        $ cat deployment-issues.yaml
        
    
        apiVersion: apps/v1
        kind: Deployment
        metadata:
        name: issues
        labels:
           app: issues
        spec:
        selector:
           matchLabels:
              app: issues
        replicas: 1
        template:
           metadata:
              annotations:
              vault.hashicorp.com/agent-inject: 'true'
              vault.hashicorp.com/role: 'internal-app'
              vault.hashicorp.com/agent-inject-secret-database-config.txt: 'internal/data/database/config'
              vault.hashicorp.com/agent-inject-template-database-config.txt: |
                 {{- with secret "internal/data/database/config" -}}
                 postgresql://{{ .Data.data.username }}:{{ .Data.data.password }}@postgres:5432/wizard
                 {{- end -}}
              labels:
              app: issues
           spec:
              serviceAccountName: internal-app
              containers:
              - name: issues
                 image: jweissig/app:0.0.1
        
    
5.  Apply the deployment defined in `deployment-issues.yaml`.
    
        $ kubectl apply --filename deployment-issues.yaml
        deployment.apps/issues created
        
    
6.  Get all the pods in the `lab-security-offsite-${INITIALS}` namespace.
    
        $ kubectl get pods
        NAME                      READY   STATUS     RESTARTS   AGE
        issues-79d8bf7cdf-dkdlq   0/2     Init:0/1   0          3s
        
    
    Current context
    
    The same command is issued but the results are different because you are now in a different namespace.
    
    The `issues` deployment creates a pod but it is **NEVER** ready.
    
7.  Display the logs of the `vault-agent-init` container in the `issues` pod.
    
        $ kubectl logs \
           $(kubectl get pod -l app=issues -o jsonpath="{.items[0].metadata.name}") \
           --container vault-agent-init
        
    
    The initialization process fails because the namespace is not authorized:
    
        ...
        [INFO]  auth.handler: authenticating
        [ERROR] auth.handler: error authenticating: error="Error making API request.
        
        URL: PUT http://vault.lab-security-${INITIALS}.svc:8200/v1/auth/kubernetes/login
        Code: 500. Errors:
        
        * namespace not authorized" backoff=1.9882590740000001
        
    
    The namespace, `lab-security-offsite-${INITIALS}` is not assigned to any Vault Kubernetes authentication role. This failure to authenticate causes the deployment to fail initialization.
    
8.  Start an interactive shell session on the `vault-0` pod in the `lab-security-${INITIALS}` namespace.
    
    ```
    $ kubectl exec --namespace `lab-security-${INITIALS}` -it vault-0 -- /bin/sh
    / $
    ```
    
    Your system prompt is replaced with a new prompt `/ $`. Commands issued at this prompt are executed on the `vault-0` container.
    
9.  Create a Kubernetes authentication role named `offsite-app`.
    
    ```sh
    $ export INITIALS=ns # CHANGEME
    $ vault write auth/kubernetes/role/offsite-app \
        bound_service_account_names=internal-app \
        bound_service_account_namespaces=lab-security-offsite-${INITIALS} \
        policies=internal-app \
        ttl=24h
    ```
        
    
    Successful output from the command resembles this example:
    
        Success! Data written to: auth/kubernetes/role/offsite-app
        
    
10.  Exit the `vault-0` pod.
    
11.  Display the deployment patch `patch-issues.yaml`.
    
    ```yaml
    spec:
    template:
        metadata:
            annotations:
            vault.hashicorp.com/agent-inject: 'true'
            vault.hashicorp.com/agent-inject-status: 'update'
            vault.hashicorp.com/role: 'offsite-app'
            vault.hashicorp.com/agent-inject-secret-database-config.txt: 'internal/data/database/config'
            vault.hashicorp.com/agent-inject-template-database-config.txt: |
                {{- with secret "internal/data/database/config" -}}
                postgresql://{{ .Data.data.username }}:{{ .Data.data.password }}@postgres:5432/wizard
                {{- end -}}
    ```

    The patch performs an update to set the `vault.hashicorp.com/role` to the Vault Kubernetes role `offsite-app`.
    
12.  Patch the `issues` deployment defined in `patch-issues.yaml`.
   
    ```sh
    $ kubectl patch deployment issues --patch "$(cat patch-issues.yaml)"
    deployment.apps/issues patched
    ```

    A new `issues` pod starts alongside the existing pod. When it is ready the original terminates and removes itself from the list of active pods.
    
13.  Get all the pods in the `lab-security-offsite-${INITIALS}` namespace.
    
    ```sh
    $ kubectl get pods
    NAME                      READY   STATUS    RESTARTS   AGE
    issues-7fd66f98f6-ffzh7   2/2     Running   0          94s
    ```
    
    Wait until the re-deployed `issues` pod reports that it is [`Running`](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-phase) and ready (`2/2`).
    
14.  Finally, display the secret written to the `issues` container in the `issues` pod.

    ```sh
    $ kubectl exec \
        $(kubectl get pod -l app=issues -o jsonpath="{.items[0].metadata.name}") \
        --container issues -- cat /vault/secrets/database-config.txt
    ```

    The secrets are rendered in a PostgreSQL connection string is present on the container:

    ```
    postgresql://db-readonly-user:db-secret-password@postgres:5432/wizard
    ```

You launched Vault and the injector service with the Vault Helm chart. Learn more about the Vault Helm chart by reading the [documentation](https://developer.hashicorp.com/vault/docs/platform/k8s), exploring the [project source code](https://github.com/hashicorp/vault-helm), reading the blog post announcing the ["Injecting Vault Secrets into Kubernetes Pods via a Sidecar"](https://www.hashicorp.com/blog/injecting-vault-secrets-into-kubernetes-pods-via-a-sidecar), or the documentation for [Agent Sidecar Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector)

Then you deployed several applications to demonstrate how this new injector service retrieves and writes these secrets for the applications to use. Explore how pods can retrieve them [directly via network requests](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-minikube-consul) or secrets [mounted on ephemeral volumes](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-secret-store-driver).

An alternative option to the agent is the is the [Vault Secrets Operator](https://developer.hashicorp.com/vault/docs/platform/k8s/vso). It is a Kubernetes operator specifically made to aid in management of Vault on Kubernetes. This is similar to the Vault Agent sidecar, but in a Kubernetes native fashion.

*   [Agent Sidecar Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector)
*   [Mutating admission webhook](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#mutatingadmissionwebhook)
*   [Sidecar container pattern](https://medium.com/bb-tutorials-and-thoughts/kubernetes-learn-sidecar-container-pattern-6d8c21f873d)
*   [Vault Secrets Operator](https://developer.hashicorp.com/vault/docs/platform/k8s/vso)
*   [Integrating Hashicorp Vault in OpenShift 4](https://www.redhat.com/en/blog/integrating-hashicorp-vault-in-openshift-4)
*   [developer.hashicorp.com](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar)
