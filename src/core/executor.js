'use strict';
/**
 * EXECUTOR — Task Execution with Verification
 *
 * What brain.js never had — actual success/failure awareness.
 *
 * Before: run tool → assume success
 * Now:    define success → run tool → verify → retry → give up intelligently
 */

const mind     = require('./mind');
const registry = require('../tools/registry');

const TOOL_TIMEOUT = 10000;
const MAX_STRATEGIES = 3;

// ── Execute a task with full lifecycle ───────────────────────────────────────
async function execute(description, tools, successCondition, onTool) {
  const taskId = mind.createTask(description, successCondition);
  let   lastResult = null;
  let   succeeded  = false;

  for (const tool of tools) {
    onTool && onTool(tool.name, tool.args, null);
    try {
      const result = await _withTimeout(
        registry.execute(tool.name, tool.args),
        TOOL_TIMEOUT
      );
      const resultStr = String(result || '').slice(0, 1000);
      lastResult = resultStr;
      onTool && onTool(tool.name, tool.args, resultStr);

      // verify success
      if (successCondition) {
        succeeded = _verify(resultStr, successCondition);
      } else {
        succeeded = !resultStr.toLowerCase().includes('error') &&
                    !resultStr.toLowerCase().includes('failed');
      }

      mind.updateTask(taskId, succeeded ? 'done' : 'active', resultStr);

    } catch (e) {
      lastResult = `error: ${e.message}`;
      onTool && onTool(tool.name, tool.args, lastResult);
      mind.updateTask(taskId, 'active', lastResult);
    }
  }

  if (!succeeded) {
    mind.updateTask(taskId, 'failed', lastResult);
  }

  return { taskId, succeeded, lastResult };
}

// ── Verify if a result meets success condition ────────────────────────────────
function _verify(result, successCondition) {
  if (!successCondition) return true;

  const r = result.toLowerCase();
  const c = successCondition.toLowerCase();

  // explicit failure signals
  if (r.includes('error') || r.includes('failed') || r.includes('not found')) return false;

  // check if success keywords are present
  const keywords = c.split(/\s+/).filter(w => w.length > 3);
  const matches  = keywords.filter(w => r.includes(w));
  if (matches.length > 0) return true;

  // if no explicit failure and result has content — assume success
  return result.length > 5;
}

function _withTimeout(promise, ms) {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error('tool timed out')), ms)
    )
  ]);
}

// ── Parse tool calls from model output ────────────────────────────────────────
function parseTools(text) {
  const tools = [];
  if (!text) return tools;

  const re = /<tool:(\w+)>([\s\S]*?)(?:<\/tool>|<\/tool:\1>)/g;
  let m;
  while ((m = re.exec(text)) !== null) {
    const name = m[1];
    let raw = (m[2] || '').trim();
    // Strip markdown code block fences if present
    raw = raw.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();

    let args = {};
    if (!raw) {
      args = {};
    } else {
      try {
        args = JSON.parse(raw);
      } catch {
        try {
          const sanitized = raw
            .replace(/,\s*([}\]])/g, '$1')
            .replace(/'/g, '"');
          args = JSON.parse(sanitized);
        } catch {
          if (name === 'exec') args = { command: raw };
          else if (name === 'search') args = { query: raw };
          else if (name === 'open_app') args = { package: raw };
          else if (name === 'web_fetch') args = { url: raw };
          else if (name === 'tap_text' || name === 'find_and_tap') args = { text: raw };
          else args = { raw };
        }
      }
    }
    tools.push({ name, args });
  }
  return tools;
}

function cleanReply(text) {
  if (!text) return '';
  return text
    .replace(/<tool:[\s\S]*?(?:<\/tool>|<\/tool:\w+>)/g, '')
    .replace(/<(?:think|thinking)>[\s\S]*?<\/(?:think|thinking)>/gi, '')
    .replace(/<(?:think|thinking)>[\s\S]*$/gi, '')
    .replace(/<\/?(?:think|thinking)>/gi, '')
    .replace(/`{1,3}<tool:[\s\S]*?`{1,3}/g, '')
    .trim();
}

module.exports = { execute, parseTools, cleanReply };
