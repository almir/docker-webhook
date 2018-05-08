#!/bin/bash
set -o pipefail

# Set path to this script
SCRIPTPATH=$(readlink -f "$(dirname "$(readlink -f ${0})")")
# Get stript's name
SCRIPTNAME=$(basename ${0})

check_and_update() {
  # Get inside the git repo directory
  cd ${SCRIPTPATH}/.. || exit
  # Get the branch currently used
  CURBRANCH=$(git rev-parse --abbrev-ref HEAD)
  # Get latest updates to the repo
  git fetch --all && \
  git reset --hard origin/${CURBRANCH}

  # Get latest release of webhook and release used in this repo
  LATEST_RELEASE=$(curl -s https://api.github.com/repos/adnanh/webhook/releases/latest | grep tag_name | awk -F ': "' '{ print $2 }' | awk -F '",' '{ print $1 }')
  LOCAL_RELEASE=$(grep "^ENV.*WEBHOOK_VERSION" ${SCRIPTPATH}/../Dockerfile | awk '{ print $NF }')

  # Compare releases and update Dockerfile in case they differ
  if [[ "${LOCAL_RELEASE}" != "${LATEST_RELEASE}" ]] && [[ -n ${LATEST_RELEASE} ]]; then
    sed -i "s/WEBHOOK_VERSION.*/WEBHOOK_VERSION ${LATEST_RELEASE}/g" ${SCRIPTPATH}/../Dockerfile
    sed -i "s/WEBHOOK_VERSION.*/WEBHOOK_VERSION: \"${LATEST_RELEASE}\"/g" ${SCRIPTPATH}/../.circleci/config.yml
    git commit -am "- bump webhook version to ${LATEST_RELEASE}"
    git push origin ${CURBRANCH} && \
    curl -s -X POST -H "Content-Type: application/json" \
      -d '{"tag_name":"'${LATEST_RELEASE}'","target_commitish":"'${CURBRANCH}'","name":"webhook '${LATEST_RELEASE}'","body":"Release for webhook version '${LATEST_RELEASE}'.","draft":false,"prerelease":false}' \
      https://${GITHUB_USER}:${GITHUB_PASS}@api.github.com/repos/${GITHUB_USER}/docker-webhook/releases
  fi
}

argmissing() {
  echo "Usage: $0 --user GITHUB_USERNAME --password GITHUB_PASSWORD [--write-crontab]"
  echo
  echo "Switches:"
  echo -e "\t--user\t\t\tSpecify GitHub username - required."
  echo -e "\t--password\t\tSpecify GitHub password - required."
  echo -e "\t--write-crontab\t\tAdd crontab entry for this script - optional."
  echo
  echo "Examples:"
  echo -e "\t$0 --user someuser --password somepassword"
  echo -e "\t$0 --user someuser --password somepassword --write-crontab"
  exit 1
}

# Translate script arguments to variables
GITHUB_USER=$(echo "$@" | awk -F "--user " '{ print $2 }' | awk '{ print $1 }')
GITHUB_PASS=$(echo "$@" | awk -F "--password " '{ print $2 }' | awk '{ print $1 }')

if [[ -z ${GITHUB_USER} ]] || [[ -z ${GITHUB_PASS} ]]; then
  argmissing
else
  if [[ -n $(echo "$@" | grep "\-\-write-crontab") ]]; then
    if [[ -z $(crontab -l | grep ${SCRIPTNAME}) ]]; then
      echo "Crontab entry is being created."
      crontab -l | { cat; echo -e "# Check for webhook releases every five minutes\n*/5 * * * * ${SCRIPTPATH}/${SCRIPTNAME} --user ${GITHUB_USER} --password ${GITHUB_PASS} > /dev/null"; } | crontab -
    else
      echo "Crontab entry already exists."
    fi
  fi
  check_and_update
fi

exit 0
