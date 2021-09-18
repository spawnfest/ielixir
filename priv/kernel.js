define([
  "require",
  "codemirror/lib/codemirror",
  "codemirror/addon/mode/loadmode",
  "base/js/namespace",
  "base/js/events",
  "base/js/utils",
], function (require, CodeMirror, CodemirrorLoadmode, IPython, events, utils) {
  var onload = function () {
    console.log("Kernel elixir kernel.js is loading.");

    // add here logic that should be run once per **page load**
    // like adding specific UI, or changing the default value
    // of codecell highlight.
    enableElixirMode(CodeMirror)

    // Set tooltips to be triggered after 800ms
    IPython.tooltip.time_before_tooltip = 800;

    // IPython keycodes.
    var space = 32;
    var downArrow = 40;
    IPython.keyboard.keycodes.down = downArrow; // space

    IPython.CodeCell.options_default["cm_config"]["mode"] = "ielixir";

    utils.requireCodeMirrorMode("elixir", function () {
      // Create a multiplexing mode that uses Elixir highlighting by default but
      // doesn't highlight command-line directives.
      CodeMirror.defineMode("ielixir", function (config) {
        return CodeMirror.multiplexingMode(
          CodeMirror.getMode(config, "elixir"),
          {
            open: /:(?=!)/, // Matches : followed by !, but doesn't consume !
            close: /^(?!!)/, // Matches start of line not followed by !, doesn't consume character
            mode: CodeMirror.getMode(config, "text/plain"),
            delimStyle: "delimit",
          }
        );
      });

      cells = IPython.notebook.get_cells();
      for (var i in cells) {
        c = cells[i];
        if (c.cell_type === "code") {
          // Force the mode to be Elixir
          // This is necessary, otherwise sometimes highlighting just doesn't happen.
          // This may be an IPython bug.
          c.code_mirror.setOption("mode", "ielixir");
          c.force_highlight("ielixir");
        }
      }
    });
    if (IPython.notebook.set_codemirror_mode) {
      IPython.notebook.set_codemirror_mode("ielixir");
    }

    // Prevent the pager from surrounding everything with a <pre>
    IPython.Pager.prototype.append_text = function (text) {
      this.pager_element
        .find(".container")
        .append($("<div/>").html(IPython.utils.autoLinkUrls(text)));
    };

    events.on("shell_reply.Kernel", function () {
      // Add logic here that should be run once per reply.

      // Highlight things with a .highlight-code class
      // The id is the mode with with to highlight
      $(".highlight-code").each(function () {
        var $this = $(this),
          $code = $this.html(),
          $unescaped = $("<div/>").html($code).text();

        $this.empty();

        // Never highlight this block again.
        this.className = "";

        CodeMirror(this, {
          value: $unescaped,
          mode: this.id,
          lineNumbers: false,
          readOnly: true,
        });
      });
    });
    console.log("IElixir kernel.js should have been loaded.");
  }; // end def of onload
  return { onload: onload };
});

var enableElixirMode = function (CodeMirror) {
  // Below code comes from CodeMirror Mode Elixir project (c) by Marijn
  // Haverbeke, Ian Walter, et al. available at
  // https://github.com/ianwalter/codemirror-mode-elixir

  // CodeMirror Mode Elixir, copyright (c) by Marijn Haverbeke, Ian Walter, and
  // others. Distributed under an MIT license: http://codemirror.net/LICENSE.
  CodeMirror.defineMode("elixir", (config) => {
    const wordObj = (words) => {
      let o = {};
      for (var i = 0, e = words.length; i < e; ++i) o[words[i]] = true;
      return o;
    };

    const keywords = wordObj([
      "alias",
      "case",
      "cond",
      "def",
      "defmodule",
      "defp",
      "defstruct",
      "defprotocol",
      "defimpl",
      "defmacro",
      "quote",
      "unquote",
      "receive",
      "fn",
      "do",
      "else",
      "else if",
      "end",
      "false",
      "if",
      "in",
      "next",
      "rescue",
      "for",
      "true",
      "unless",
      "when",
      "nil",
      "raise",
      "throw",
      "try",
      "catch",
      "after",
      "with",
      "require",
      "use",
      "__MODULE__",
      "__FILE__",
      "__DIR__",
      "__ENV__",
      "__CALLER__",
    ]);
    const indentWords = wordObj([
      "def",
      "defmodule",
      "defp",
      "case",
      "cond",
      "rescue",
      "try",
      "catch",
      "->",
    ]);
    const dedentWords = wordObj(["end"]);
    const matching = { "[": "]", "{": "}", "(": ")" };

    let curPunc;

    const chain = (newtok, stream, state) => {
      state.tokenize.push(newtok);
      return newtok(stream, state);
    };

    const tokenBase = (stream, state) => {
      if (stream.sol() && stream.match('"""') && stream.eol()) {
        state.tokenize.push(readBlockComment);
        return "comment";
      }

      if (stream.eatSpace()) {
        return null;
      }

      let ch = stream.next();
      let m;

      if (ch === "'" || ch === '"') {
        return chain(readQuoted(ch, "string", ch === '"'), stream, state);
      } else if (ch === "/") {
        let currentIndex = stream.current().length;
        if (stream.skipTo("/")) {
          let searchTill = stream.current().length;
          let balance = 0; // balance brackets

          stream.backUp(stream.current().length - currentIndex);

          while (stream.current().length < searchTill) {
            const chchr = stream.next();
            if (chchr === "(") {
              balance += 1;
            } else if (chchr === ")") {
              balance -= 1;
            }
            if (balance < 0) {
              break;
            }
          }

          stream.backUp(stream.current().length - currentIndex);

          if (balance === 0) {
            return chain(readQuoted(ch, "string-2", true), stream, state);
          }
        }

        return "operator";
      } else if (ch === "%") {
        let style = "string";
        let embed = true;

        if (stream.eat("s")) {
          style = "atom";
        } else if (stream.eat(/[WQ]/)) {
          style = "string";
        } else if (stream.eat(/[r]/)) {
          style = "string-2";
        } else if (stream.eat(/[wxq]/)) {
          style = "string";
          embed = false;
        }

        let delim = stream.eat(/[^\w\s=]/);

        if (!delim) {
          return "operator";
        }

        if (matching.propertyIsEnumerable(delim)) {
          delim = matching[delim];
        }

        return chain(readQuoted(delim, style, embed, true), stream, state);
      } else if (ch === "#") {
        stream.skipToEnd();
        return "comment";
      } else if (
        ch === "<" &&
        (m = stream.match(/^<-?[\`\"\']?([a-zA-Z_?]\w*)[\`\"\']?(?:;|$)/))
      ) {
        return chain(readHereDoc(m[1]), stream, state);
      } else if (ch === "0") {
        if (stream.eat("x")) {
          stream.eatWhile(/[\da-fA-F]/);
        } else if (stream.eat("b")) {
          stream.eatWhile(/[01]/);
        } else {
          stream.eatWhile(/[0-7]/);
        }
        return "number";
      } else if (/\d/.test(ch)) {
        stream.match(/^[\d_]*(?:\.[\d_]+)?(?:[eE][+\-]?[\d_]+)?/);
        return "number";
      } else if (ch === "?") {
        while (stream.match(/^\\[CM]-/)) {}

        if (stream.eat("\\")) {
          stream.eatWhile(/\w/);
        } else {
          stream.next();
        }
        return "string";
      } else if (ch === ":") {
        if (stream.eat("'")) {
          return chain(readQuoted("'", "atom", false), stream, state);
        }
        if (stream.eat('"')) {
          return chain(readQuoted('"', "atom", true), stream, state);
        }

        // :> :>> :< :<< are valid symbols
        if (stream.eat(/[\<\>]/)) {
          stream.eat(/[\<\>]/);
          return "atom";
        }

        // :+ :- :/ :* :| :& :! are valid symbols
        if (stream.eat(/[\+\-\*\/\&\|\:\!]/)) {
          return "atom";
        }

        // Symbols can't start by a digit
        if (stream.eat(/[a-zA-Z$@_\xa1-\uffff]/)) {
          stream.eatWhile(/[\w$\xa1-\uffff]/);
          // Only one ? ! = is allowed and only as the last character
          stream.eat(/[\?\!\=]/);
          return "atom";
        }

        return "operator";
      } else if (ch === "@" && stream.match(/^@?[a-zA-Z_\xa1-\uffff]/)) {
        stream.eat("@");
        stream.eatWhile(/[\w\xa1-\uffff]/);
        return "variable-2";
      } else if (ch === "$") {
        if (stream.eat(/[a-zA-Z_]/)) {
          stream.eatWhile(/[\w]/);
        } else if (stream.eat(/\d/)) {
          stream.eat(/\d/);
        } else {
          stream.next(); // Must be a special global like $: or $!
        }
        return "variable-3";
      } else if (/[a-zA-Z_\xa1-\uffff]/.test(ch)) {
        stream.eatWhile(/[\w\xa1-\uffff]/);
        stream.eat(/[\?\!]/);
        if (stream.eat(":")) {
          return "atom";
        }
        return "ident";
      } else if (
        ch === "|" &&
        (state.varList || state.lastTok === "{" || state.lastTok === "do")
      ) {
        curPunc = "|";
        return null;
      } else if (/[\(\)\[\]{}\\;]/.test(ch)) {
        curPunc = ch;
        return null;
      } else if (ch === "-" && stream.eat(">")) {
        return "arrow";
      } else if (ch === "|" && stream.eat(">")) {
        return "pipe";
      } else if (/[=+\-\/*:\.^%<>~|]/.test(ch)) {
        if (ch === "." && !stream.eatWhile(/[=+\-\/*:\.^%<>~|]/)) {
          curPunc = ".";
        }
        return "operator";
      } else {
        return null;
      }
    };

    const tokenBaseUntilBrace = (depth) => {
      if (!depth) {
        depth = 1;
      }

      return (stream, state) => {
        if (stream.peek() === "}") {
          if (depth === 1) {
            state.tokenize.pop();
            return state.tokenize[state.tokenize.length - 1](stream, state);
          } else {
            state.tokenize[state.tokenize.length - 1] = tokenBaseUntilBrace(
              depth - 1
            );
          }
        } else if (stream.peek() === "{") {
          state.tokenize[state.tokenize.length - 1] = tokenBaseUntilBrace(
            depth + 1
          );
        }
        return tokenBase(stream, state);
      };
    };

    const tokenBaseOnce = () => {
      let alreadyCalled = false;
      return (stream, state) => {
        if (alreadyCalled) {
          state.tokenize.pop();
          return state.tokenize[state.tokenize.length - 1](stream, state);
        }
        alreadyCalled = true;
        return tokenBase(stream, state);
      };
    };

    const readQuoted = (quote, style, embed, unescaped) => {
      return (stream, state) => {
        let escaped = false;
        let ch;

        if (state.context.type === "read-quoted-paused") {
          state.context = state.context.prev;
          stream.eat("}");
        }

        while ((ch = stream.next()) != null) {
          // eslint-disable-line
          if (ch === quote && (unescaped || !escaped)) {
            state.tokenize.pop();
            break;
          }

          if (embed && ch === "#" && !escaped) {
            if (stream.eat("{")) {
              if (quote === "}") {
                state.context = {
                  prev: state.context,
                  type: "read-quoted-paused",
                };
              }
              state.tokenize.push(tokenBaseUntilBrace());
              break;
            } else if (/[@\$]/.test(stream.peek())) {
              state.tokenize.push(tokenBaseOnce());
              break;
            }
          }

          escaped = !escaped && ch === "\\";
        }

        return style;
      };
    };

    const readHereDoc = (phrase) => {
      return (stream, state) => {
        if (stream.match(phrase)) {
          state.tokenize.pop();
        } else {
          stream.skipToEnd();
        }
        return "string";
      };
    };

    const readBlockComment = (stream, state) => {
      if (stream.sol() && stream.match('"""') && stream.eol()) {
        state.tokenize.pop();
      }
      stream.skipToEnd();
      return "comment";
    };

    return {
      startState: () => {
        return {
          tokenize: [tokenBase],
          indented: 0,
          context: { type: "top", indented: -config.indentUnit },
          continuedLine: false,
          lastTok: null,
          varList: false,
        };
      },
      token: (stream, state) => {
        curPunc = null;

        // if (stream.sol()) {
        //   state.indented = stream.indentation()
        // }

        let style = state.tokenize[state.tokenize.length - 1](stream, state);
        let kwtype;
        let thisTok = curPunc;

        if (style === "ident") {
          let word = stream.current();

          style =
            state.lastTok === "."
              ? "property"
              : keywords.propertyIsEnumerable(stream.current())
              ? "keyword"
              : /^[A-Z]/.test(word)
              ? "tag"
              : state.lastTok === "def" ||
                state.lastTok === "class" ||
                state.varList
              ? "def"
              : "variable";

          const isColumnIndent = stream.column() === stream.indentation();
          if (style === "keyword") {
            thisTok = word;
            if (indentWords.propertyIsEnumerable(word)) {
              kwtype = "indent";
            } else if (dedentWords.propertyIsEnumerable(word)) {
              kwtype = "dedent";
            } else if ((word === "if" || word === "unless") && isColumnIndent) {
              kwtype = "indent";
            } else if (
              word === "do" &&
              state.context.indented < state.indented
            ) {
              kwtype = "indent";
            }
          }
        }

        if (curPunc || (style && style !== "comment")) {
          state.lastTok = thisTok;
        }

        if (curPunc === "|") {
          state.varList = !state.varList;
        }

        if (kwtype === "indent" || /[\(\[\{]/.test(curPunc)) {
          state.context = {
            prev: state.context,
            type: curPunc || style,
            indented: state.indented,
          };
        } else if (
          (kwtype === "dedent" || /[\)\]\}]/.test(curPunc)) &&
          state.context.prev
        ) {
          state.context = state.context.prev;
        }

        if (stream.eol()) {
          state.continuedLine = curPunc === "\\" || style === "operator";
        }

        return style;
      },
      // indent: (state, textAfter) => {
      //   if (state.tokenize[state.tokenize.length - 1] !== tokenBase) {
      //     return 0
      //   }
      //   let firstChar = textAfter && textAfter.charAt(0)
      //   let ct = state.context
      //   let closing = ct.type === matching[firstChar] ||
      //     ct.type === 'keyword' && /^(?:end|until|else|else if|when|rescue)\b/.test(textAfter)
      //   return ct.indented + (closing ? 0 : config.indentUnit) +
      //     (state.continuedLine ? config.indentUnit : 0)
      // },
      electricInput: /^\s*(?:end|rescue|else if|else|catch\})$/,
      lineComment: "#",
    };
  });

  CodeMirror.defineMIME("text/x-elixir", "elixir");
};
