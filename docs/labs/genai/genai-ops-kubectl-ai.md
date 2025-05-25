# Streamline kubernetes operations with `kubectl-ai`

## Lab Outline

- **Duration:** 30 minutes
- **Objective:** Enable engineering students to quickly install, configure, and use `kubectl-ai` to manage Kubernetes clusters using natural language queries.

## Content

- [Streamline kubernetes operations with `kubectl-ai`](#streamline-kubernetes-operations-with-kubectl-ai)
  - [Lab Outline](#lab-outline)
  - [Content](#content)
  - [Prerequisites](#prerequisites)
  - [Introduction to `kubectl-ai`](#introduction-to-kubectl-ai)
  - [Lab Instructions](#lab-instructions)
    - [Installing `kubectl-ai` (Linux and MacOS)](#installing-kubectl-ai-linux-and-macos)
    - [Running `kubectl-ai` with OpenAI compatible provider](#running-kubectl-ai-with-openai-compatible-provider)
    - [Running individual queries](#running-individual-queries)
    - [Generating YAML manifests](#generating-yaml-manifests)
    - [Explore additional examples](#explore-additional-examples)
  - [Conclusion](#conclusion)

## Prerequisites

- OpenAI compatible LLM server exposing models (`Mistral Large` as example in this lab).
    - If running this lab as part of a workshop, one is given to you e.g. `http://models.apps.devopsp.mop.demo`.
- Access to a terminal with `kubectl` installed and configured to a K8s cluster.
  - We recommend [minikube](https://minikube.sigs.k8s.io/docs/start/) or [kind](https://kind.sigs.k8s.io/docs/user/quick-start/).

## Introduction to `kubectl-ai`

- `kubectl-ai` is an AI-powered Kubernetes assistant that allows you to manage clusters using plain English, translating your requests into valid `kubectl` commands or YAML manifests.
- It supports multiple AI models (Google Gemini by default, OpenAI, Azure OpenAI, local LLMs like Ollama).
- **Key benefits**: reduces Kubernetes learning curve, boosts productivity, and democratizes cluster access.

## Lab Instructions

### Installing `kubectl-ai` (Linux and MacOS)

1. Install the `kubectl-ai` plugin:
    ```sh
    curl -sSL https://raw.githubusercontent.com/GoogleCloudPlatform/kubectl-ai/main/install.sh | bash
    ```
2. Verify installation:
    ```sh
    kubectl ai --help
    ```

### Running `kubectl-ai` with OpenAI compatible provider

```sh
export OPENAI_API_KEY=sk-CHANGEME
export OPENAI_ENDPOINT=http://CHANGEME/v1
kubectl ai --llm-provider=openai --model=mistral-large
```

!!! note
    If running this lab in a workshop setup, you should have a [LiteLLM proxy](https://docs.litellm.ai/docs/simple_proxy) OpenAI compatible server running, you can find the route (endpoint) and API key in the `ai-models` namespace. The API key is the `LITELLM_MASTER_KEY` value of the `litellm-secret` secret.

This has started an interactive session, you can start asking questions with follow-up:

```
Create an nginx deployment with 1 replicas in the genai-CHANGEME namespace
```
```
Get the logs
```

### Running individual queries

Try the following commands and observe the AI-generated `kubectl` commands. Adapt as required by your context:

```sh
kubectl ai "Create an nginx deployment with 1 replicas in the genai-CHANGEME namespace for OpenShift" --llm-provider=openai --model=mistral-large 
```
```sh
kubectl ai "Scale my nginx deployment to 2 replicas" --llm-provider=openai --model=mistral-large 
```
```sh
kubectl ai "Show me all pods that failed in the last hour" --llm-provider=openai --model=mistral-large 
```
```sh
kubectl ai "Generate a HorizontalPodAutoscaler YAML for the web-api deployment" --llm-provider=openai --model=mistral-large 
```
```sh
kubectl ai "Show me the logs for the nginx pod in the genai-CHANGEME namespace" --llm-provider=openai --model=mistral-large 
```

### Generating YAML manifests

```bash
kubectl ai "Write a deployment with nginx and a service that exposes port 80" --llm-provider=openai --model=mistral-large 
```

The tool will generate YAML and ask if you want to apply it.

### Explore additional examples

Explore these extra scenarios to deepen your hands-on experience with `kubectl-ai`. These examples cover both common and advanced Kubernetes operations, all using natural language.

**Create and Update Resources**

```
Create an nginx deployment with 1 replicas
```
```
Update the nginx deployment to use 2 replicas and expose port 8080
```
```
Create a genai-CHANGEME namespace, then create an nginx pod in that namespace
```

**Service and Networking**

```
Create a service of type LoadBalancer for my nginx deployment
```
```
Expose the redis deployment on port 6379 as a ClusterIP service
```
```
Set up a NetworkPolicy to only allow traffic to the frontend deployment from the genai-CHANGEME namespace
```

**Pod and Deployment Management**

```
Restart all pods in the genai-CHANGEME namespace
```
```
Delete the pod named my-app-123 in the genai-CHANGEME namespace
```
```
Show the status of all deployments in the kube-system namespace
```

**Logs and Troubleshooting**

```
Fetch logs for the nginx app in the genai-CHANGEME namespace
```
```
Show events for the backend deployment
```
```
Explain the error in this log 
```

!!! note
    (pipe a log file: `cat error.log | kubectl-ai "explain the error` --llm-provider=openai --model=mistral-large )

**Scaling and Autoscaling**

```
Scale the production app to 2 replicas
```
```
Generate a HorizontalPodAutoscaler YAML for the api-server deployment
```

**Advanced YAML Generation**

```
Write a deployment YAML for a Python app using the image python:3.9 with environment variable DEBUG=true
```
```
Create a ConfigMap named app-config with keys LOG_LEVEL=debug and TIMEOUT=30
```
```
Generate a Secret manifest with username=admin and password=Pa\$\$w0rd
```

**Batch and Multiple Resources**

```
Create a namespace called genai-CHANGEME, then deploy a busybox pod in it
```
```
Create a deployment and a service for a MongoDB database in the genai-CHANGEME namespace
```


## Conclusion

By the end of this lab, you should be able to:
- Install and configure `kubectl-ai`
- Use natural language to manage Kubernetes resources
- Generate and apply YAML manifests using AI

Feel free to experiment with your own queries and switch to other provided LLMs, then reflect on the productivity gains from using AI-powered Kubernetes tooling, make sure to also challenge the risks of such tools in the context of Agentic AI.
