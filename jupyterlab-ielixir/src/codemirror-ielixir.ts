import * as CodeMirror from 'codemirror';
import "codemirror-mode-elixir";

CodeMirror.defineMode("ielixir", (config) => {
  let hmode = CodeMirror.getMode(config, "elixir");
  return CodeMirror.multiplexingMode(
    hmode,
    {
      open: /:(?=!)/, // Matches : followed by !, but doesn't consume !
      close: /^(?!!)/, // Matches start of line not followed by !, doesn't consume character
      mode: CodeMirror.getMode(config, "text/plain"),
      delimStyle: "delimit",
    },
    {
      open: /\[r\||\[rprint\||\[rgraph\|/,
      close: /\|\]/,
      mode: CodeMirror.getMode(config, "text/x-rsrc"),
      delimStyle: "delimit",
    }
  );
});

CodeMirror.defineMIME("text/x-ielixir", "ielixir");

CodeMirror.modeInfo.push({
  ext: ["ex"],
  mime: "text/x-ielixir",
  mode: "ielixir",
  name: "ielixir",
});
