#/bin/bash

if [ -n "${USER}" -a -n "${GITEA_HOSTNAME}" -a -n "${GITEA_TOKEN}" ]; then
  true
else
  echo "\${USER}, \${GITEA_HOSTNAME}, and \${GITEA_TOKEN} must be set." 
  echo "\${USER} is ${USER}."
  echo "\${GITEA_HOSTNAME} is ${GITEA_HOSTNAME}."
  echo "\${GITEA_TOKEN} is ${GITEA_TOKEN}."
  exit
fi

# Replace username and git credential with the environment variables.
find ./ -type f -name "*.yaml" -print0 | xargs -0 sed -i "s/<USER>/${USER}/g"
find ./ -type f -name "*.yaml" -print0 | xargs -0 sed -i "s/<GITEA_HOSTNAME>/${GITEA_HOSTNAME}/g"
find ./ -type f -name "*.yaml" -print0 | xargs -0 sed -i "s/<GITEA_TOKEN>/${GITEA_TOKEN}/g"

# Push to remote manifests repository.
git config --global user.name gitea
git config --global user.email admin@gitea.com
git commit -a -m "Replaced GITEA_ info"
git push
