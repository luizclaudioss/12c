# Especificação de Comportamento — HP 12C (HP12CCore)

Este documento resume a especificação de comportamento adotada pelo motor `HP12CCore` (seções 2 a 9 do plano de arquitetura).

## 2. Parser de Teclas → Instrução (`KeyParser`)
`KeyParser` mantém estado pendente: `.none`, `.f`, `.g`, `.sto`, `.stoDot`, `.stoArith(op)`, `.rcl`, `.rclDot`, `.rclG`, `.gto`, `.gto1(d)`, `.gtoDot`, `.gtoDot1(d)`.
- Os anunciadores `f` / `g` permanecem acesos enquanto o estado pendente for `.f` / `.g`.
- Instruções não-programáveis (executadas mesmo no modo PRGM): `P/R`, `SST`, `BST`, `GTO . nn`, `CLEAR PRGM`, `CLEAR PREFIX`, `MEM`, `ON` (e erro imediato `error(6)` em `STO op 5..9/.`). Todas as demais são gravadas em modo PRGM.

## 3. Numéricos, Pilha e Buffer de Entrada
- Valores internos em `Double`, normalizados para 10 dígitos significativos (`%.9e`).
- Overflow `|v| > 9.999999999e99`: limita a `±9.999999999e99` e ativa `overflow` (display pisca até a próxima tecla).
- Underflow `0 < |v| < 1e-99`: zera para `0`.
- NaN/domínio inválido: `Error 0`.
- Pilha RPN `X, Y, Z, T`, `LSTx` e flag `liftEnabled`.
- Buffer de entrada: mantissa (até 10 dígitos com `.` opcional), sinal, expoente (0–2 dígitos com sinal). `CHS` durante a entrada alterna o sinal do expoente (se em EEX) ou da mantissa. `EEX` fora de entrada inicia mantissa `"1"`.
- `ENTER` encerra entrada, faz push e define `liftEnabled = false`. `CLx`, `Σ+`, `Σ−` definem `liftEnabled = false`. Demais operações definem `liftEnabled = true`.
- Códigos de erro: `0` matemática, `1` overflow em aritmética de registrador (`STO op`), `2` estatística, `3` IRR não encontrado, `4` memória de programa, `5` juros compostos/depreciação, `6` registrador indisponível/`Nj` inválido/fluxos em excesso, `7` IRR sem troca de sinal, `8` calendário, `Pr Error` reset da memória contínua. Todo erro é limpo pela próxima tecla (que não é executada).

## 4. Registradores, Limpezas e Modos
- 20 registradores de armazenamento (`R0..R9`, `R.0..R.9`), 20 contagens `nj` (padrão 1), 5 registradores financeiros (`n, i, PV, PMT, FV`).
- Regra de armazenar vs. calcular nas teclas financeiras (`n, i, PV, PMT, FV`): `finComputeFlag` fica verdadeiro após armazenar/calcular uma variável financeira ou `12×`/`12÷`; qualquer outra instrução executada zera o flag.
- `f CLEAR Σ`: zera `R1..R6` e `X, Y, Z, T`. `FIN`: zera `n, i, PV, PMT, FV`. `REG`: zera armazenamento, `nj=1`, financeiros, pilha e `LSTx` (mantém programa). `PRGM`: limpa programa e zera `pc` no modo PRGM; apenas `pc=0` no modo RUN. `PREFIX`: cancela prefixo e exibe mantissa de 10 dígitos de `X` por 1,5 s.
- `g MEM`: exibe `P-XX r-YY` por 1,5 s.
- `ON` alterna energia. Estando desligada, `.` agenda alternância do separador europeu e `−` agenda reset da memória contínua (`Pr Error`) ao ligar novamente.

## 5. Display
- 1 célula de sinal + 10 células de 7 segmentos à esquerda (`.` e `,` acoplam-se à célula anterior).
- Modos `FIX k` (com fallback para `SCI` se `|arredondado| >= 1e10` ou se valor não-nulo arredondar para `0`) e `SCI` (mantissa de 6 decimais + sinal de expoente + 2 dígitos).
- Entrada em digitação exibe vírgulas de milhar e ponto decimal à direita caso nenhum tenha sido digitado; com `EEX`, mantissa em até 7 células + espaço/sinal + 2 dígitos de expoente.
- Após `g DATE`: data com 6 casas + espaços + dígito do dia da semana (1=seg..7=dom) na última célula.
- Modo PRGM: `00-` na linha 0; `nn-` + códigos alinhados à direita nas 7 células restantes (vírgula após o primeiro código quando houver 3 códigos e o último tiver 2 dígitos, ex. `43,33 00`, `45,43 14`).

## 6. Financeiro
- TVM com suporte a períodos fracionários (juros simples ou compostos via `STO EEX` / anunciador `C`), modo `BEG`/`END`, cálculo direto de `PV`, `PMT`, `FV`, `n` (arredondando para cima com tolerância `1e-9`) e `i` (Newton + varredura/bisseção).
- `AMORT`: iteração período a período arredondando juros conforme modo de display ativo.
- `INT`: juros simples base 360 (`X`), `-PV` (`Y`), base 365 (`Z`).
- Fluxos de caixa (`CF0`, `CFj`, `Nj`, `RCL g CFj`, `RCL g Nj`), `NPV`, `IRR`, `RCL g R/S` (IRR com chute inicial em `X`).
- Títulos (`PRICE`, `YTM`): base actual/actual semestral, valor de resgate 100.
- Depreciação (`SL`, `SOYD`, `DB`).

## 7. Calendário e Estatística
- Datas `M.DY` e `D.MY` no intervalo 15/10/1582 a 25/11/4046 (calendário gregoriano / JDN). `DATE` e `ΔDYS` (dias reais em `X` e 30/360 em `Y`).
- Estatística (`Σ+`, `Σ−`, `x̄`, `s`, `x̄w`, regressão linear `ŷ,r` e `x̂,r`).

## 8. Programação
- Até 99 linhas; memória dinâmica compartilha blocos de 7 linhas com registradores `R.9`..`R7` (zerando registradores liberados ao programa).
- Execução passo a passo (`step()`), condicionais (`x≤y`, `x=0`), `R/S`, `PSE` (pausa de 1 s), `SST`/`BST`.
- Desvios `GTO nn`:
  - Em execução de programa: `nn == 0` ou `nn > program.count` (dentro de `allocatedLines`) encerram em `pc = 0` e param a execução (linhas não gravadas equivalem a `GTO 00`); `nn > allocatedLines` gera `Error 4`; caso contrário salta para `nn`.
  - No teclado em modo RUN (`g GTO nn`) e modo PRGM (`g GTO . nn`): `nn > program.count` gera `Error 4`. Gravação aceita `00`..`99`.

## 9. API do Motor (`HP12CCore`)
Classe `HP12C` com `state: HP12CState` (`Codable`), `press(_:)`, `step()`, `runUntilStopped(maxSteps:)`, propriedades de display/anunciadores/mensagens/estado e auxiliares `backspace()`, `setX(_:)`, `toggleSeparator()`, `resetContinuousMemory()`.
