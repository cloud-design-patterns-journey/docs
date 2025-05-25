<!--- cSpell:ignore ICPA openshiftconsole Theia userid toolset crwexposeservice gradlew bluemix ocinstall Mico crwopenlink crwopenapp swaggerui gitpat gituser  buildconfig yourproject wireframe devenvsetup viewapp crwopenlink  atemplatized rtifactoryurlsetup Kata Koda configmap Katacoda checksetup cndp katacoda checksetup Linespace igccli regcred REPLACEME Tavis pipelinerun openshiftcluster invokecloudshell cloudnative sampleapp bwoolf hotspots multicloud pipelinerun Sricharan taskrun Vadapalli Rossel REPLACEME cloudnativesampleapp artifactoryuntar untar Hotspot devtoolsservices Piyum Zonooz Farr Kamal Arora Laszewski  Roadmap roadmap Istio Packt buildpacks automatable ksonnet jsonnet targetport podsiks SIGTERM SIGKILL minikube apiserver multitenant kubelet multizone Burstable checksetup handson  stockbffnode codepatterns devenvsetup newwindow preconfigured cloudantcredentials apikey Indexyaml classname  errorcondition tektonpipeline gradlew gitsecret viewapp cloudantgitpodscreen crwopenlink cdply crwopenapp -->

Develop an example application with a three-tier microservices architecture and deploy it into Red Hat OpenShift on premises, on AWS, Azure or IBM Cloud. This OpenShift development environment has been pre-configured with a sample [SDLC](https://cio-wiki.org/wiki/Software_Development_Life_Cycle_(SDLC)) (Software Delivery Life Cycle).

## Business Need

In this guide, imagine you have completed an Enterprise Design Thinking Workshop and the result is an MVP statement that defines the desired business outcomes. Use the steps below to help deliver this MVP quickly while following [Garage Method best practices](https://www.ibm.com/garage/method/cloud/).

### MVP Statement

An **MVP** is a **first hill**. Here's the hill statement for the MVP we're going to build:

- **Who**: Distribution employees in each of the regional warehouses

- **What**: A secure web application that enables easy access to list of product [SKU](https://en.wikipedia.org/wiki/Stock_keeping_unit) inventory levels and inventory locations

- **Wow**: Make the system appealing and easy to use. Develop it quickly as a minimum viable product. Use the latest managed container runtimes and DevOps best practices to enable post MVP feature improvements. Simulate a release to a _Test_ environment.

## Architecture

We will build an application that is made up of microservices in three-tier architecture. Each tier encapsulates a clean separation of concerns. Each app microservice component will be modelled using _microservices_ and use a number of [polyglot](https://searchsoftwarequality.techtarget.com/definition/polyglot-programming) programming languages and frameworks. Data will be stored in a NoSQL Database.

![Architecture](../inventory-application/images/architecture.png)

### User interface

The user experience for the application has been designed by the design team and this drives the requirements for the development team.

### Technical Requirements

The Micro services should adhere to the following technical requirements:

- Microservices
    - Stateless
    - REST APIs
    - Polyglot
- DevOps with CI/CD (continuous integration and continuous delivery) 
    - Use in cluster CI technology to be efficient and secure
    - Use latest GitOps best practices
    - Monitoring and logging
    - Code analysis
    - App security
- Deployed to Red Hat OpenShift cluster which is based on Kubernetes open source technology
- Follow the [Carbon Design System](https://www.carbondesignsystem.com/) user experience

## Fast Track Guide

### Deploy inventory service

- Create a new repository for the service from the [Inventory Service Solution](https://github.com/cloud-design-patterns-journey/inv-svc-solution/generate) template. Make the cloned repository public.

    !!! warning
        In order to prevent naming collisions if you are running this as part of a workshop, chose the GitHub organization you have been invited to as `Owner` and name the repository `inv-svc-${UNIQUE_SUFFIX}`, replacing `${UNIQUE_SUFFIX}` with your team name or initials.

- Deploy this application with Tekton:

    !!! note
        You should have the [`tkn`](https://github.com/tektoncd/cli?tab=readme-ov-file#installing-tkn), [`tkn pac`](https://pipelinesascode.com/docs/guide/cli/#install) and `oc` CLIs installed. `oc` can be installed through the help section of your OpenShift console.
    
  - In the OpenShift web console, click on the user ID on the top right, click on **Copy login command** and get the OpenShift login command, which includes a token.
  
    ![OpenShift Login](../../../../inventory-application/images/common/LoginCommand.png)
  
  - Click on **Display Token**, copy the Login with the token. oc login command will log you in. Run the login command in your terminal:
  
    ```sh
    oc login --token=<OCP_TOKEN> --server=<OCP_SERVER>
    ```

  - Create a new `inventory-${UNIQUE_SUFFIX}-dev` project (setting the `UNIQUE_SUFFIX` environment variables with your team name or initials to have a unique name):

    ```sh
    export UNIQUE_SUFFIX=ns # CHANGEME
    oc new-project inventory-${UNIQUE_SUFFIX}-dev
    ```

  - Create `registry-config` and `ci-config` secrets required for your pipeline runs to access your container registry:

    ```yaml
    cat <<EOF | oc apply -f -
    ---
    kind: Secret
    apiVersion: v1
    metadata:
      name: registry-config
      namespace: inventory-${UNIQUE_SUFFIX}-dev
    stringData:
      config.json: '{"auths":...}' # CHANGEME
    type: Opaque
    ---
    kind: Secret
    apiVersion: v1
    metadata:
      name: ci-config
      namespace: inventory-${UNIQUE_SUFFIX}-dev
    stringData:
      img-namespace: library # CHANGEME
      img-server: core.harbor.example.com # CHANGEME
    type: Opaque
    EOF
    ```

  !!! note
      If you are doing this lab as part of a workshop secrets have been created for you in the `ci-tools` namespace, you just need to copy them:

        ```sh
        oc get secret registry-config -n ci-tools -o yaml | sed "s/ci-tools/inventory-${UNIQUE_SUFFIX}-dev/g" | oc apply -f -
        oc get secret ci-config -n ci-tools -o yaml | sed "s/ci-tools/inventory-${UNIQUE_SUFFIX}-dev/g" | oc apply -f -
        ```

  - Clone the repo locally:

    ```sh
    git clone https://github.com/cloud-design-patterns-journey/inv-svc-${UNIQUE_SUFFIX}.git
    cd inv-svc-${UNIQUE_SUFFIX}
    ```

  - Create the tekton pipeline for the backend service your new project:

    ```sh
    oc adm policy add-scc-to-user privileged -z pipeline
    tkn pac create repository
    ```

  !!! note
      - `tkn pac create repository` assumes you have [Pipelines-as-Code](https://pipelinesascode.com/docs/install/overview/) already setup on your cluster and Git provider. If you are running this lab as part of a workshop, this has been configured for you, make sure you use the provided GitHub organization when you create yout Git repository from template above.
      - `oc adm policy add-scc-to-user privileged -z pipeline` will make sure that the Tekton pipeline will be able to escalade privileges in your `inventory-${UNIQUE_SUFFIX}-dev` project/namespace.

  - In OpenShift console (**Pipelines Section > Pipelines > Repositories**), edit the newly created `Repository` YAML to add cluster specific configuration (e.g. image repository):

    ```yaml
    ...
    spec:
      params:
      - name: img-server
        secret_ref:
          name: ci-config
          key: img-server
      - name: img-namespace
        secret_ref:
          name: ci-config
          key: img-namespace
    ...
    ```

  - Kickoff the pipeline by making a dummy commit:

      ```bash
      echo "\n" >> README.md
      git add .
      git commit -s -m "Dummy commit"
      git push
      ```

- The CI pipeline should kick off. Once complete, you will be able to test the deployed service by going to the service route (accessible from openshift Console, or by running `oc get route`).

### Deploy backend for frontend (BFF)

- Create a new repository from the [BFF Solution](https://github.com/cloud-design-patterns-journey/inv-bff-solution/generate) template.

    !!! warning
        In order to prevent naming collisions if you are running this as part of a workshop, chose the GitHub organization you have been invited to as `Owner` and name the repository `inv-bff-${UNIQUE_SUFFIX}`, replacing `${UNIQUE_SUFFIX}` with your team name or initials.

- Deploy this application with Tekton:

    !!! note
        You should have the [`tkn`](https://github.com/tektoncd/cli?tab=readme-ov-file#installing-tkn), [`tkn pac`](https://pipelinesascode.com/docs/guide/cli/#install) and `oc` CLIs installed. `oc` can be installed through the help section of your OpenShift console.
    
- In the OpenShift web console, click on the user ID on the top right, click on **Copy login command** and get the OpenShift login command, which includes a token.

  ![OpenShift Login](../../../images/common/LoginCommand.png)

- Click on **Display Token**, copy the Login with the token. oc login command will log you in. Run the login command in your terminal:

    ```sh
    oc login --token=<OCP_TOKEN> --server=<OCP_SERVER>
    ```

- Move to your `inventory-${UNIQUE_SUFFIX}-dev` project created in previous lab:

    ```sh
    export UNIQUE_SUFFIX=ns # CHANGEME
    oc project inventory-${UNIQUE_SUFFIX}-dev
    ```

- Clone the repo locally:

    ```sh
    git clone https://github.com/cloud-design-patterns-journey/inv-bff-${UNIQUE_SUFFIX}.git
    cd inv-bff-${UNIQUE_SUFFIX}
    ```

- Create the tekton pipeline for the backend service your new project:

    ```sh
    oc adm policy add-scc-to-user privileged -z pipeline
    tkn pac create repository
    ```

!!! note
    - `tkn pac create repository` assumes you have [Pipelines-as-Code](https://pipelinesascode.com/docs/install/overview/) already setup on your cluster and Git provider. If you are running this lab as part of a workshop, this has been configured for you, make sure you use the provided GitHub organization when you create yout Git repository from template above.
    - `oc adm policy add-scc-to-user privileged -z pipeline` will make sure that the Tekton pipeline will be able to escalade privileges in your `inventory-${UNIQUE_SUFFIX}-dev` project/namespace.

- In OpenShift console (**Pipelines Section > Pipelines > Repositories**), edit the newly created `Repository` YAML to add cluster specific configuration (e.g. image repository):

    ```yaml
    ...
    spec:
      params:
      - name: img-server
        secret_ref:
          name: ci-config
          key: img-server
      - name: img-namespace
        secret_ref:
          name: ci-config
          key: img-namespace
    ...
    ```

- Last step before kicking off the pipeline is to make sure our Kubernetes/OpenShift deployment will get the `SERVICE_URL` environment variable configured. To do so, create a secret and patch the deployment to use it as source for environment variables:

    ```sh
    oc create secret generic inv-bff-${UNIQUE_SUFFIX}-config --from-literal=SERVICE_URL=http://inv-svc-${UNIQUE_SUFFIX}:8080
    ```

- Update the Tekton `deploy` task in `.tekton/tasks.yaml` to set deployment environment variables from newly created secret:

    ```yaml title=".tekton/tasks.yaml"
    ...
          echo "Creating deployment $(params.app-name)"
          kubectl create deploy $(params.app-name) --image $(params.image) --port $(params.app-port)
          kubectl set env --from=secret/$(params.app-name)-config deployment/$(params.app-name) # NEW LINE
          kubectl expose deploy $(params.app-name) --port $(params.app-port)
          oc expose svc $(params.app-name)
    ...
    ```

- After validation, commit and push the changes to git:
    ```bash
    git add .
    git commit -s -m "Updates CI"
    git push
    ```

- CI pipeline should be kicked off, you can test the hosted application once complete.

### Deploy frontend microservice

- Create a new repository from the [UI Solution](https://github.com/cloud-design-patterns-journey/inv-ui-solution/generate) template.

    !!! warning
        In order to prevent naming collisions if you are running this as part of a workshop, chose the GitHub organization you have been invited to as `Owner` and name the repository `inv-ui-${UNIQUE_SUFFIX}`, replacing `${UNIQUE_SUFFIX}` with your team name or initials.

- Deploy this application with Tekton:

    !!! note
        You should have the [`tkn`](https://github.com/tektoncd/cli?tab=readme-ov-file#installing-tkn), [`tkn pac`](https://pipelinesascode.com/docs/guide/cli/#install) and `oc` CLIs installed. `oc` can be installed through the help section of your OpenShift console.
    
- In the OpenShift web console, click on the user ID on the top right, click on **Copy login command** and get the OpenShift login command, which includes a token.

  ![OpenShift Login](../../../images/common/LoginCommand.png)

- Click on **Display Token**, copy the Login with the token. oc login command will log you in. Run the login command in your terminal:

    ```sh
    oc login --token=<OCP_TOKEN> --server=<OCP_SERVER>
    ```

- Move to your `inventory-${UNIQUE_SUFFIX}-dev` project created in previous lab:

    ```sh
    export UNIQUE_SUFFIX=ns # CHANGEME
    oc project inventory-${UNIQUE_SUFFIX}-dev
    ```

- Clone the repo locally:

    ```sh
    git clone https://github.com/cloud-design-patterns-journey/inv-ui-${UNIQUE_SUFFIX}.git
    cd inv-ui-${UNIQUE_SUFFIX}
    ```

- Create the tekton pipeline for the backend service your new project:

    ```sh
    oc adm policy add-scc-to-user privileged -z pipeline
    tkn pac create repository
    ```

!!! note
    - `tkn pac create repository` assumes you have [Pipelines-as-Code](https://pipelinesascode.com/docs/install/overview/) already setup on your cluster and Git provider. If you are running this lab as part of a workshop, this has been configured for you, make sure you use the provided GitHub organization when you create yout Git repository from template above.
    - `oc adm policy add-scc-to-user privileged -z pipeline` will make sure that the Tekton pipeline will be able to escalade privileges in your `inventory-${UNIQUE_SUFFIX}-dev` project/namespace.

- In OpenShift console (**Pipelines Section > Pipelines > Repositories**), edit the newly created `Repository` YAML to add cluster specific configuration (e.g. image repository):

    ```yaml
    ...
    spec:
      params:
      - name: img-server
        secret_ref:
          name: ci-config
          key: img-server
      - name: img-namespace
        secret_ref:
          name: ci-config
          key: img-namespace
    ...
    ```

- Last step before kicking off the pipeline is to make sure our Kubernetes/OpenShift deployment will get the `API_HOST` environment variable configured. To do so, create a secret and patch the deployment to use it as source for environment variables:

    ```sh
    oc create secret generic inv-ui-${UNIQUE_SUFFIX}-config --from-literal=API_HOST=http://inv-bff-${UNIQUE_SUFFIX}:3000
    ```

- Update the Tekton `deploy` task in `.tekton/tasks.yaml` to set deployment environment variables from newly created secret:

    ```yaml title=".tekton/tasks.yaml"
    ...
          echo "Creating deployment $(params.app-name)"
          kubectl create deploy $(params.app-name) --image $(params.image) --port $(params.app-port)
          kubectl set env --from=secret/$(params.app-name)-config deployment/$(params.app-name) # NEW LINE
          kubectl expose deploy $(params.app-name) --port $(params.app-port)
          oc expose svc $(params.app-name)
    ...
    ```

- After validation, commit and push the changes to git:
    ```bash
    git add .
    git commit -s -m "Updates CI"
    git push
    ```

- CI pipeline should be kicked off, you can test the hosted application once complete.

## Summary

Congrats! You have now completed the Micro App Guide demonstrating the Inventory solution.
