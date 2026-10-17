// Phone ping (Gotify, via ~/.agents/bin/notify.sh) when an opencode session goes idle,
// i.e. the agent finished and is waiting for you. opencode has no Stop hook, so this
// plugin is the equivalent of Claude Code's Stop hook and Codex's `notify`.
// The message is the agent's last reply; notify.sh adds instance, repo, branch and dir.

import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

const NOTIFY = join(homedir(), ".agents/bin/notify.sh");

function notify(args, payload) {
  try {
    const child = spawn(NOTIFY, args, { stdio: ["pipe", "ignore", "ignore"], detached: true });
    child.on("error", () => {});
    child.stdin.end(payload ? JSON.stringify(payload) : "");
    child.unref();
  } catch {
    // never break opencode over a notification
  }
}

async function lastReply(client, sessionID) {
  try {
    const res = await client.session.messages({ path: { id: sessionID } });
    const messages = res?.data ?? res ?? [];
    for (let i = messages.length - 1; i >= 0; i--) {
      const m = messages[i];
      if (m?.info?.role !== "assistant") continue;
      const text = (m.parts ?? []).filter((p) => p.type === "text").map((p) => p.text).join(" ").trim();
      if (text) return text;
    }
  } catch {
    // older opencode or no access: send without the reply
  }
  return "";
}

export const NotifyPlugin = async ({ client, directory }) => {
  notify(["hydrate"]); // cache Gotify creds now so later pings never prompt
  const children = new Set(); // subagent sessions: their idle is not "done"

  return {
    event: async ({ event }) => {
      const props = event?.properties ?? {};
      const info = props.info;
      if (info?.id && info.parentID) children.add(info.id);
      if (event?.type !== "session.idle") return;
      const sessionID = props.sessionID ?? info?.id;
      if (!sessionID || children.has(sessionID)) return;
      notify([], {
        hook_event_name: "session.idle",
        session_id: sessionID,
        cwd: directory,
        message: await lastReply(client, sessionID),
      });
    },
  };
};
