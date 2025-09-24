#!/bin/bash

# Search for the triggered log workflow using the id in the run-name
run_name="$1"
title_id=$(echo "$run_name" | cut -d "-" -f2 | sed 's#"##g' \ |
            sed 's#,##g' | sed 's# ##g' | awk 'NR==1{print $NF}')
run_search=""
while [[ $(echo "$run_search" | grep ^'      "name":' | \
            cut -d "-" -f2 | sed 's#"##g' | sed 's#,##g' | \
            sed 's# ##g' | awk 'NR==1{print $NF}') != ${title_id} ]]; do

    echo -e "\nCatching the triggered log workdlow ..."

    run_search=$(curl -s -L \
                -H "Accept: application/vnd.github+json" \
                -H "Authorization: Bearer ${GITHUB_TOKEN}" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                https://api.github.com/repos/${GITHUB_REPOSITORY}actions/workflows/log-response.yml/runs)
done

    # Check status of the run by getting private run id
    run_id=$(echo "$run_search" | grep ^'      "id":' | awk 'NR==1{print $NF}' | cut -d ":" -f2 | sed 's#,##g')
    echo -e "\nCatched the triggered log workflow! Workflow run URL: [ https://github.com/${GITHUB_REPOSITORY}/actions/runs/${run_id} ]"
