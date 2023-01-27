#!/bin/bash
ORB_EVAL_SCHEDULE_JSON_PATH=$(eval echo "${ORB_EVAL_SCHEDULE_JSON_PATH}")
DATA=$(jq '.' -c "${ORB_EVAL_SCHEDULE_JSON_PATH}")
SCHEDULE_NAME=$(jq '.name' "${ORB_EVAL_SCHEDULE_JSON_PATH}")

if echo  "${CIRCLE_BUILD_URL}" | grep -E "GitHub|gh" > /dev/null; then
        VCS="gh"
elif echo  "${CIRCLE_BUILD_URL}" | grep -E "BitBucke|bb" > /dev/null; then
        VCS="bb"
else
        VCS="circleci"
fi

URL="https://circleci.com/api/v2/project/${VCS}/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/schedule"

curl -s --request GET \
  --url "${URL}" \
  --header "Circle-Token: $CIRCLE_TOKEN" > all_schedules.json

jq '.' all_schedules.json

if jq '.' -c all_schedules.json | grep "Project not found" > /dev/null; then
  echo "The specified project is not found. Please check the project name vcs type or namespace."
  exit 1
fi

if jq ".items[] | .name" all_schedules.json | grep "${SCHEDULE_NAME}"; then
  SCHEDULE_ID=$(jq -r '.items[] | select( .name == '"${SCHEDULE_NAME}"') | .id' all_schedules.json)
  set -x
  curl -s --request PATCH \
      --url https://circleci.com/api/v2/schedule/"${SCHEDULE_ID}" \
      --header "Circle-Token: ${CIRCLE_TOKEN}" \
      --header 'content-type: application/json' \
      --data "${DATA}" > status.json
  set +x 

else

  set -x
  curl -s --request POST \
      --url "${URL}" \
      --header "Circle-Token: ${CIRCLE_TOKEN}" \
      --header 'content-type: application/json' \
      --data "${DATA}" > status.json
  set +x
    if jq '.' -c status.json | grep "Invalid input" > /dev/null; then
      echo -e "\nPlease recheck your json schedule\n"
      jq '.message' -rc status.json
      exit 1
    fi
fi

jq '.' status.json
