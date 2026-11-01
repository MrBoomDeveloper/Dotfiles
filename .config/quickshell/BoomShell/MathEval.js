.pragma library

// Small recursive-descent evaluator used by the launcher: "12*(3+4)" → "84".
// Only arithmetic is allowed — no property access, no arbitrary calls — since
// the input comes straight from the search field.

const CONSTANTS = {
    "pi": Math.PI,
    "π": Math.PI,
    "tau": Math.PI * 2,
    "τ": Math.PI * 2,
    "e": Math.E,
    "phi": (1 + Math.sqrt(5)) / 2,
    "φ": (1 + Math.sqrt(5)) / 2
}

function factorial(n) {
    if (n < 0 || Math.floor(n) !== n || n > 170)
        throw new Error("bad factorial")
    let result = 1
    for (let i = 2; i <= n; i++)
        result *= i
    return result
}

const FUNCTIONS = {
    sqrt: { min: 1, max: 1, fn: a => Math.sqrt(a[0]) },
    cbrt: { min: 1, max: 1, fn: a => Math.cbrt(a[0]) },
    abs: { min: 1, max: 1, fn: a => Math.abs(a[0]) },
    floor: { min: 1, max: 1, fn: a => Math.floor(a[0]) },
    ceil: { min: 1, max: 1, fn: a => Math.ceil(a[0]) },
    round: { min: 1, max: 1, fn: a => Math.round(a[0]) },
    trunc: { min: 1, max: 1, fn: a => Math.trunc(a[0]) },
    sign: { min: 1, max: 1, fn: a => Math.sign(a[0]) },
    exp: { min: 1, max: 1, fn: a => Math.exp(a[0]) },
    ln: { min: 1, max: 1, fn: a => Math.log(a[0]) },
    log: { min: 1, max: 2, fn: a => a.length === 2 ? Math.log(a[0]) / Math.log(a[1]) : Math.log10(a[0]) },
    log10: { min: 1, max: 1, fn: a => Math.log10(a[0]) },
    log2: { min: 1, max: 1, fn: a => Math.log2(a[0]) },
    mod: { min: 2, max: 2, fn: a => a[0] % a[1] },
    pow: { min: 2, max: 2, fn: a => Math.pow(a[0], a[1]) },
    hypot: { min: 1, max: 8, fn: a => Math.hypot.apply(null, a) },
    atan2: { min: 2, max: 2, fn: a => Math.atan2(a[0], a[1]) },
    min: { min: 1, max: 32, fn: a => Math.min.apply(null, a) },
    max: { min: 1, max: 32, fn: a => Math.max.apply(null, a) },
    deg: { min: 1, max: 1, fn: a => a[0] * 180 / Math.PI },
    rad: { min: 1, max: 1, fn: a => a[0] * Math.PI / 180 },
    fact: { min: 1, max: 1, fn: a => factorial(a[0]) },
    sin: { min: 1, max: 1, fn: a => Math.sin(a[0]) },
    cos: { min: 1, max: 1, fn: a => Math.cos(a[0]) },
    tan: { min: 1, max: 1, fn: a => Math.tan(a[0]) },
    asin: { min: 1, max: 1, fn: a => Math.asin(a[0]) },
    acos: { min: 1, max: 1, fn: a => Math.acos(a[0]) },
    atan: { min: 1, max: 1, fn: a => Math.atan(a[0]) },
    sinh: { min: 1, max: 1, fn: a => Math.sinh(a[0]) },
    cosh: { min: 1, max: 1, fn: a => Math.cosh(a[0]) },
    tanh: { min: 1, max: 1, fn: a => Math.tanh(a[0]) }
}

function isDigit(ch) {
    return ch >= "0" && ch <= "9"
}

function isLetter(ch) {
    return (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || ch === "_"
}

function tokenize(text) {
    const tokens = []
    let i = 0
    while (i < text.length) {
        const ch = text.charAt(i)

        if (ch === " " || ch === "\t" || ch === "\n") {
            i++
            continue
        }

        if (isDigit(ch) || ch === ".") {
            let j = i
            while (j < text.length && (isDigit(text.charAt(j)) || text.charAt(j) === "."))
                j++
            // Scientific notation: 1e3, 2.5E-2 (only when digits follow).
            if (j < text.length && (text.charAt(j) === "e" || text.charAt(j) === "E")) {
                let k = j + 1
                if (k < text.length && (text.charAt(k) === "+" || text.charAt(k) === "-"))
                    k++
                let digits = 0
                while (k < text.length && isDigit(text.charAt(k))) {
                    k++
                    digits++
                }
                if (digits > 0)
                    j = k
            }
            const num = Number(text.substring(i, j))
            if (!isFinite(num))
                return null
            tokens.push({ type: "num", value: num })
            i = j
            continue
        }

        if (isLetter(ch) || ch === "π" || ch === "τ" || ch === "φ") {
            let j = i + 1
            while (j < text.length && (isLetter(text.charAt(j)) || isDigit(text.charAt(j))))
                j++
            tokens.push({ type: "ident", value: text.substring(i, j).toLowerCase() })
            i = j
            continue
        }

        if (ch === "(" || ch === ")") {
            tokens.push({ type: "paren", value: ch })
            i++
            continue
        }

        if (ch === ",") {
            tokens.push({ type: "comma", value: ch })
            i++
            continue
        }

        // Typographic variants people paste from documents.
        const mapped = ch === "×" || ch === "·" ? "*"
                     : ch === "÷" ? "/"
                     : ch === "−" || ch === "–" ? "-"
                     : ch
        if ("+-*/%^".indexOf(mapped) >= 0) {
            if (mapped === "*" && text.charAt(i + 1) === "*") {
                tokens.push({ type: "op", value: "**" })
                i += 2
            } else {
                tokens.push({ type: "op", value: mapped })
                i++
            }
            continue
        }

        // Anything else makes the input "not a formula" rather than an error.
        return null
    }
    return tokens
}

// A bare number or a bare constant is not treated as math: "123" should still
// search apps. An operator or a function call is what makes it a formula.
function looksLikeMath(tokens) {
    for (let i = 0; i < tokens.length; i++) {
        const token = tokens[i]
        if (token.type === "op")
            return true
        if (token.type !== "ident")
            continue
        const next = tokens[i + 1]
        if (next && next.type === "paren" && next.value === "(")
            return true
        // Implicit multiplication with a constant: "2pi", "3e".
        const previous = tokens[i - 1]
        if (previous && (previous.type === "num"
                || (previous.type === "paren" && previous.value === ")")))
            return true
    }
    return false
}

function peek(state) {
    return state.tokens[state.pos] || null
}

function take(state) {
    return state.tokens[state.pos++] || null
}

function startsPrimary(token) {
    if (!token)
        return false
    if (token.type === "num" || token.type === "ident")
        return true
    return token.type === "paren" && token.value === "("
}

function callFunction(name, args) {
    const spec = FUNCTIONS[name]
    if (!spec || args.length < spec.min || args.length > spec.max)
        throw new Error("bad call")
    const value = spec.fn(args)
    if (typeof value !== "number")
        throw new Error("bad result")
    return value
}

function parsePrimary(state) {
    const token = take(state)
    if (!token)
        throw new Error("unexpected end")

    if (token.type === "num")
        return token.value

    if (token.type === "paren" && token.value === "(") {
        const value = parseExpression(state)
        const close = take(state)
        if (!close || close.value !== ")")
            throw new Error("missing )")
        return value
    }

    if (token.type === "ident") {
        const next = peek(state)
        if (next && next.type === "paren" && next.value === "(") {
            state.pos++
            const args = []
            const afterOpen = peek(state)
            if (afterOpen && afterOpen.type === "paren" && afterOpen.value === ")") {
                state.pos++
            } else {
                while (true) {
                    args.push(parseExpression(state))
                    const separator = take(state)
                    if (!separator)
                        throw new Error("unclosed call")
                    if (separator.type === "comma")
                        continue
                    if (separator.type === "paren" && separator.value === ")")
                        break
                    throw new Error("bad argument list")
                }
            }
            return callFunction(token.value, args)
        }
        const constant = CONSTANTS[token.value]
        if (constant !== undefined)
            return constant
        throw new Error("unknown name")
    }

    throw new Error("unexpected token")
}

function parsePower(state) {
    const base = parsePrimary(state)
    const token = peek(state)
    if (token && token.type === "op" && (token.value === "^" || token.value === "**")) {
        state.pos++
        return Math.pow(base, parseUnary(state))
    }
    return base
}

function parseUnary(state) {
    const token = peek(state)
    if (token && token.type === "op" && (token.value === "-" || token.value === "+")) {
        state.pos++
        const value = parseUnary(state)
        return token.value === "-" ? -value : value
    }
    return parsePower(state)
}

function parseTerm(state) {
    let value = parseUnary(state)
    while (true) {
        const token = peek(state)
        if (token && token.type === "op"
                && (token.value === "*" || token.value === "/" || token.value === "%")) {
            state.pos++
            const rhs = parseUnary(state)
            if (token.value === "*")
                value *= rhs
            else if (token.value === "/")
                value /= rhs
            else
                value %= rhs
            continue
        }
        // Implicit multiplication: 2pi, 3(4+5), 2sqrt(9).
        if (startsPrimary(token)) {
            value *= parseUnary(state)
            continue
        }
        break
    }
    return value
}

function parseExpression(state) {
    let value = parseTerm(state)
    while (true) {
        const token = peek(state)
        if (token && token.type === "op" && (token.value === "+" || token.value === "-")) {
            state.pos++
            const rhs = parseTerm(state)
            value = token.value === "+" ? value + rhs : value - rhs
            continue
        }
        break
    }
    return value
}

function formatNumber(value) {
    if (!isFinite(value))
        return null
    if (value === 0)
        return "0"
    if (Number.isInteger(value) && Math.abs(value) < 1e21)
        return String(value)

    const abs = Math.abs(value)
    if (abs >= 1e15 || abs < 1e-7)
        return value.toExponential(6).replace(/\.?0+e/, "e")

    // Cut binary floating point noise: 0.1 + 0.2 → 0.3 instead of 0.30000000000000004
    return String(Number(value.toPrecision(12)))
}

// Returns { value, text } for a valid formula, otherwise null.
function evaluate(input) {
    const raw = String(input || "").trim()
    if (raw.length === 0 || raw.length > 200)
        return null

    // "2,5" is a decimal comma on most European layouts. Only rewrite it when
    // the expression has no names, since in calls commas separate arguments.
    const text = /[a-zA-Zπτφ]/.test(raw) ? raw : raw.replace(/,/g, ".")

    const tokens = tokenize(text)
    if (!tokens || tokens.length === 0 || !looksLikeMath(tokens))
        return null

    let value
    try {
        const state = { tokens: tokens, pos: 0 }
        value = parseExpression(state)
        if (state.pos !== tokens.length)
            return null
    } catch (e) {
        return null
    }

    if (typeof value !== "number" || !isFinite(value))
        return null

    const formatted = formatNumber(value)
    if (formatted === null)
        return null

    return { value: value, text: formatted }
}
