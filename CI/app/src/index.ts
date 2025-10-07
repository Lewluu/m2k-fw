import process from "process";
import { Octokit } from "@octokit/rest";

const octokit = new Octokit({ auth: process.env.GITHUB_TOKEN });
const delay = (ms: number) => new Promise((res) => setTimeout(res, ms));

const [REPO_OWNER, REPO_NAME] = process.env.GITHUB_REPOSITORY!.split("/");
const GITHUB_RUN_ID = process.env.GITHUB_RUN_ID!;
const HDL_PROJECT_NAME = process.env.HDL_PROJECT_NAME!;

// Method to search for a workflow by name an return the id
const searchForWorkflowRun = async (searchName: string) => {
  let runId: number | null = null;

  while (!runId) {
    const runs = await octokit.actions.listWorkflowRuns({
      owner: REPO_OWNER,
      repo: REPO_NAME,
      workflow_id: "get-response.yml",
      event: "workflow_dispatch",
    });

    const run = runs.data.workflow_runs.find((r) => r.name === searchName);
    if (run) {
      runId = run.id;
      break;
    }

    console.log("Run not found yet, retrying...");
    await delay(2000); // Wait before retrying
  }

  if (!runId) {
    throw new Error(
      "Failed to find triggered workflow run ID after multiple attempts.",
    );
  }

  console.log(`Triggered workflow run ID: ${runId}`);

  return runId;
};

// Method to monitor testing status - TO BE IMPLEMENTED

// Method to monitor build workflow and log its status
const monitorWorkflowRun = async (searchName: string) => {
  // Search for triggered workflow run by name
  const runId = await searchForWorkflowRun(searchName);

  // Monitor the workflow run status until it completes
  let status = "in_progress";
  while (status === "in_progress") {
    const { data: runData } = await octokit.actions.getWorkflowRun({
      owner: REPO_OWNER,
      repo: REPO_NAME,
      run_id: runId,
    });

    status = runData.status!;
    console.log(`Workflow run status: ${status}`);

    if (status === "completed") {
      console.log(
        `Workflow run completed with conclusion: ${runData.conclusion}`,
      );
      if (runData.conclusion !== "success") {
        throw new Error(
          `Workflow run failed with conclusion: ${runData.conclusion}`,
        );
      }
      break;
    }

    await delay(5000); // Wait before checking again
  }
};

// Method to get data of log build workflow
const getLogData = async (searchName: string) => {
  // Search for triggered workflow run by name
  const runId = await searchForWorkflowRun(searchName);

  // Fetch the logs for the workflow run
  const logsResponse = await octokit.actions.downloadWorkflowRunLogs({
    owner: REPO_OWNER,
    repo: REPO_NAME,
    run_id: runId,
  });

  console.log(`Logs URL: ${logsResponse.url}`);
};

// Main starting point
(async () => {
  try {
    // Check workflow run for build
    await monitorWorkflowRun(
      `HDL-Build-for-${HDL_PROJECT_NAME}_${GITHUB_RUN_ID}`,
    );
    await getLogData(
      `Output-for-HDL-Build-for-${HDL_PROJECT_NAME}_${GITHUB_RUN_ID}`,
    );

    // Check workflow run for publish
    await monitorWorkflowRun(
      `HDL-Publish-for-${HDL_PROJECT_NAME}_${GITHUB_RUN_ID}`,
    );
    await getLogData(
      `Output-for-HDL-Publish-for-${HDL_PROJECT_NAME}_${GITHUB_RUN_ID}`,
    );
  } catch (error) {
    console.error("Error monitoring workflows status:", error);
    process.exit(1);
  }
})();
