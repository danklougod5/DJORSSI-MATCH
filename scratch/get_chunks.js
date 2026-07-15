const fs = require('fs');
const readline = require('readline');

const rl = readline.createInterface({
  input: fs.createReadStream('/Users/mac/.gemini/antigravity-ide/brain/e1ed7c03-0b3a-4efe-bcc7-2682b2284074/.system_generated/logs/transcript.jsonl'),
  output: process.stdout,
  terminal: false
});

rl.on('line', (line) => {
  try {
    const data = JSON.parse(line);
    if (data.step_index === 135) {
      console.log(JSON.stringify(data.tool_calls[0].args, null, 2));
      process.exit(0);
    }
  } catch (e) {
    // ignore parsing errors on other lines
  }
});
