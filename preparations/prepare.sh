#!/bin/bash

ID=$(oc whoami)
if [ ${ID} == system:admin -o ${ID} == admin ]; then
  true
else
  echo "Login as admin or system:admin user with the oc login command."
  exit 1
fi

# Demo environment - no user creation needed
# All operations will be performed with admin privileges

# Install OpenShift Gitops Operator
echo "$(date '+%F %T') Installing OpenShift Gitops Operator"
oc apply -f files/openshift-gitops-operator.yaml
sleep 30

while ! oc get csv -n openshift-gitops-operator -l operators.coreos.com/openshift-gitops-operator.openshift-gitops-operator | grep Succeeded
do
  sleep 20
done

# Install Gitea Operator
echo "$(date '+%F %T') Installing Gitea Operator."
oc apply -f files/gitea-operator.yaml
sleep 30

while ! oc get csv -n gitea-operator -l operators.coreos.com/gitea-operator.gitea-operator | grep Succeeded
do
  sleep 20
done

# Create Projects for demo environment
echo "$(date '+%F %T') Creating demo projects"

# Create projects
oc get ns demo-develop 2>/dev/null  || {
    oc new-project demo-develop
}
oc get ns demo-staging 2>/dev/null  || {
    oc new-project demo-staging
}
oc get ns demo-production 2>/dev/null  || {
    oc new-project demo-production
}

# Grants permissions to ArgoCD instances to manage resources in target namespaces
oc label ns demo-develop argocd.argoproj.io/managed-by=openshift-gitops --overwrite
oc label ns demo-staging argocd.argoproj.io/managed-by=openshift-gitops --overwrite
oc label ns demo-production argocd.argoproj.io/managed-by=openshift-gitops --overwrite

# Create Gitea instance
oc apply -f files/gitea.yaml -n demo-develop
while ! oc get route -n demo-develop | grep gitea
do
  sleep 20
done

# Wait for Gitea to be ready
while true; do
  successful_status=$(oc -n demo-develop get gitea gitea -o json | jq -r '.status.conditions[] | select(.type == "Successful") | .status')

  if [[ "$successful_status" == "True" ]]; then
    echo "Completed Gitea setup for demo environment."
    break
  fi

  # Wait for Gitea initialization to complete
  sleep 20
done

# Migrate repository using Gitea API
GITEA_HOST=$(oc get route gitea -n demo-develop -o jsonpath='{.spec.host}')

echo "$(date '+%F %T') Migrating repositories to Gitea for demo environment"

# Wait for Gitea to be fully ready
sleep 10

# Create APP repository using Gitea API
curl -X POST "http://${GITEA_HOST}/api/v1/repos/migrate" \
  -H "Content-Type: application/json" \
  -u "gitea:openshift" \
  -d '{
    "clone_addr": "'${APP_REPO}'",
    "repo_name": "'${APP_REPO_NAME}'",
    "uid": 1,
    "private": false
  }' 2>/dev/null || echo "Warning: Failed to migrate ${APP_REPO_NAME}, may already exist"

# Create CONFIG repository using Gitea API
if [ -n "${CONFIG_REPO_TOKEN}" ]; then
  # Private repository with token
  curl -X POST "http://${GITEA_HOST}/api/v1/repos/migrate" \
    -H "Content-Type: application/json" \
    -u "gitea:openshift" \
    -d '{
      "clone_addr": "'${CONFIG_REPO}'",
      "repo_name": "'${CONFIG_REPO_NAME}'",
      "uid": 1,
      "private": false,
      "auth_username": "'${CONFIG_REPO_USER}'",
      "auth_token": "'${CONFIG_REPO_TOKEN}'"
    }' 2>/dev/null || echo "Warning: Failed to migrate ${CONFIG_REPO_NAME}, may already exist"
else
  # Public repository
  curl -X POST "http://${GITEA_HOST}/api/v1/repos/migrate" \
    -H "Content-Type: application/json" \
    -u "gitea:openshift" \
    -d '{
      "clone_addr": "'${CONFIG_REPO}'",
      "repo_name": "'${CONFIG_REPO_NAME}'",
      "uid": 1,
      "private": false
    }' 2>/dev/null || echo "Warning: Failed to migrate ${CONFIG_REPO_NAME}, may already exist"
fi

echo "$(date '+%F %T') Repository migration completed for demo environment"

# Extending timeout Web Terminal Operator
oc -n openshift-operators annotate devworkspacetemplate -l console.openshift.io/terminal=true web-terminal.redhat.com/unmanaged-state="true"
oc -n openshift-operators patch devworkspacetemplate web-terminal-exec --type merge --type='json' -p '[{"op": "replace", "path": "/spec/components/0/container/env/0/value", "value":"6h"}]'

# ArgoCD setup
oc create clusterrolebinding appprojects-edit --clusterrole=appprojects.argoproj.io-v1alpha1-edit --group=system:authenticated
oc create clusterrolebinding applications-edit --clusterrole=applications.argoproj.io-v1alpha1-edit --group=system:authenticated
oc patch argocd openshift-gitops -n openshift-gitops --type='json' -p='[{"op": "replace", "path": "/spec/rbac/policy", "value":"g, system:authenticated, role:admin\n"}]'