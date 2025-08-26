#!/bin/bash

# Trigger private repository workflow
post=$(curl -s -i -L -X POST \
        --url "https://api.github.com/repos/${PRIVATE_ORG}/${PRIVATE_REPO}/actions/workflows/${PRIVATE_WORKFLOW}/dispatches" \
        --header "Accept: application/vnd.github+json" \
        --header "Authorization: Bearer ${GH_TRIGGER_TOKEN}" \
        -d \
        '{
            "ref":"develop",
            "inputs": {
                "hdl-project-repo":"https://github.com/analogdevicesinc/m2k-fw.git",
                "hdl-project-branch":"master",
                "hdl-project-name":"m2k-fw",
                "vivado-version":"'${VIVADO_VERSION}'",
                "package-version":"'${PACKAGE_VERSION}'",
                "trigger-id":"'${TRIGGER_ID}'"
                }
        }')

if [[ ! -z $(echo "$post" | grep "HTTP/2 20*" ) ]]; then
    echo -e "\nPost request to trigger private workflow successful!"

    # Search for the triggered build using the opensource sent run id
    run_search=""
    while [[ $(echo "$run_search" | grep ^'      "name":' | \
                cut -d "-" -f2 | sed 's#"##g' | sed 's#,##g' | \
                sed 's# ##g' | awk 'NR==1{print $NF}') != ${TRIGGER_ID} ]]; do

        echo -e "\nCatching the triggered build ..."

        run_search=$(curl -s -L \
                    -H "Accept: application/vnd.github+json" \
                    -H "Authorization: Bearer ${GH_TRIGGER_TOKEN}" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    https://api.github.com/repos/adi-innersource/hdl-builds/actions/workflows/${PRIVATE_WORKFLOW}/runs)
    done

    # Check status of the run by getting private run id
    run_id=$(echo "$run_search" | grep ^'      "id":' | awk 'NR==1{print $NF}' | cut -d ":" -f2 | sed 's#,##g')
    echo -e "\nCatched the triggered build! Build m2k-fw run id: [ ${run_id} ]"
    echo -e "\nChecking status of m2k-fw build ..."

    run_status=""
    while [[ "$run_status" != "completed" ]]; do
        sleep 60
        status_request=$(curl -s -L \
                        -H "Accept: application/vnd.github+json" \
                        -H "Authorization: Bearer ${GH_TRIGGER_TOKEN}" \
                        -H "X-GitHub-Api-Version: 2022-11-28" \
                        https://api.github.com/repos/adi-innersource/hdl-builds/actions/runs/${run_id})
        run_status=$(echo "$status_request" grep ^'  "status":' | cut -d ":" -f2 | sed 's#"##g' | sed 's#,##g' | sed 's# ##g')

        echo "Status of m2k-fw build: ${run_status} ..."
    done
    echo -e "\nBuild finished! Getting result ..."

    # Get build result conclusion
    conclusion=$(echo "$status_request"| grep ^'      "conclusion":' | \
                    awk 'NR==1{print $NF}' | cut -d ":" -f2 | sed 's#,##g')

    if [ "$conclusion" != "success" ]; then
        echo -e "\nBuild conclusion: ${conclusion}!"
        exit 1
    else
        echo -e "\nBuild finished successfuly!"
    fi

else
    echo "\nPost request to trigger private workflow failed ..."
    echo "$post"
    exit 1
fi
