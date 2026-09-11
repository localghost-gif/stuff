{.push stackTrace:off, profiler:off.}

import std/[asyncdispatch, asyncnet, strutils, parseopt, os, net]

const
  cLime  = "\e[92m"
  cRed   = "\e[91m"
  cReset = "\e[0m"

  mSucc = "[" & cLime & ">" & cReset & "]"
  mScan = "[" & cLime & "S" & cReset & "]"
  mEvid = "[" & cLime & "E" & cReset & "]"
  mFail = "[" & cRed  & "F" & cReset & "]"
  wOpen = cLime & "OPEN" & cReset

type
  ScanConfig = object
    target: string
    startPort: int
    endPort: int
    timeout: int
    batchSize: int
    grabBanners: bool
    outputFile: string

  OSConfidence = enum
    confLow = "Low (heuristic inference)"
    confMedium = "Medium (single banner confirmation)"
    confHigh = "High (multi-service correlation)"

  OSGuess = object
    summary: string
    probability: int
    confidence: OSConfidence
    evidence: seq[string]

var
  conf = ScanConfig(
    target: "",
    startPort: 1,
    endPort: 10000,
    timeout: 1000,
    batchSize: 300,
    grabBanners: true,
    outputFile: ""
  )
  osClues: seq[string] = @[]
  observedOpenPorts: seq[int] = @[]

proc safeClose(s: AsyncSocket) =
  try: s.close() except: discard

proc stripAnsi(s: string): string =
  var inEsc = false
  result = ""
  for c in s:
    if c == '\e':
      inEsc = true
    elif inEsc and c == 'm':
      inEsc = false
    elif not inEsc:
      result.add(c)

proc recordPortForOS(port: int) =
  observedOpenPorts.add(port)

proc analyzeBannerForOS(banner: string) =
  let b = banner.toLowerAscii()

  if b.contains("ubuntu"):
    osClues.add("Banner artifact: 'Ubuntu' matched in service banner")
  elif b.contains("debian"):
    osClues.add("Banner artifact: 'Debian' matched in service banner")
  elif b.contains("centos"):
    osClues.add("Banner artifact: 'CentOS' matched in service banner")
  elif b.contains("red hat") or b.contains("rhel"):
    osClues.add("Banner artifact: 'Red Hat/RHEL' matched in service banner")
  elif b.contains("alpine"):
    osClues.add("Banner artifact: 'Alpine' matched in service banner")
  elif b.contains("freebsd"):
    osClues.add("Banner artifact: 'FreeBSD' matched in service banner")

  if b.contains("microsoft") or b.contains("iis/"):
    osClues.add("Banner artifact: 'Microsoft/IIS' matched in service banner")
  elif b.contains("windows"):
    osClues.add("Banner artifact: 'Windows' matched in service banner")

proc deduceOS(): OSGuess =
  var
    linuxScore = 0
    windowsScore = 0
    bsdScore = 0
    specificDistro = ""

  for clue in osClues:
    let c = clue.toLowerAscii()
    if c.contains("ubuntu"):
      linuxScore += 3
      if specificDistro == "": specificDistro = "Ubuntu"
    elif c.contains("debian"):
      linuxScore += 3
      if specificDistro == "": specificDistro = "Debian"
    elif c.contains("centos") or c.contains("red hat") or c.contains("alpine"):
      linuxScore += 3
    elif c.contains("windows") or c.contains("microsoft"):
      windowsScore += 3
    elif c.contains("freebsd"):
      bsdScore += 3

  if linuxScore == 0 and windowsScore == 0:
    if 3389 in observedOpenPorts or (445 in observedOpenPorts and 22 notin observedOpenPorts):
      windowsScore += 1
      osClues.add("Port profile: Common Windows services detected (RDP/SMB without SSH)")
    if 22 in observedOpenPorts or 111 in observedOpenPorts:
      linuxScore += 1
      osClues.add("Port profile: Common Unix/Linux services detected (SSH/RPCbind)")

  let totalScore = linuxScore + windowsScore + bsdScore

  if totalScore == 0:
    return OSGuess(
      summary: "Undetermined (insufficient banner/port data)",
      probability: 0,
      confidence: confLow,
      evidence: @["No recognizable OS signatures discovered in banners or port layout"]
    )

  if linuxScore > windowsScore and linuxScore > bsdScore:
    let distro = if specificDistro != "": " (" & specificDistro & ")" else: ""
    let pct = min(95, 40 + (linuxScore * 15))
    let conf = if linuxScore >= 6: confHigh elif linuxScore >= 3: confMedium else: confLow
    return OSGuess(
      summary: "Likely Linux / Unix-like" & distro,
      probability: pct,
      confidence: conf,
      evidence: osClues
    )
  elif windowsScore > linuxScore:
    let pct = min(95, 40 + (windowsScore * 15))
    let conf = if windowsScore >= 6: confHigh elif windowsScore >= 3: confMedium else: confLow
    return OSGuess(
      summary: "Likely Microsoft Windows",
      probability: pct,
      confidence: conf,
      evidence: osClues
    )
  else:
    return OSGuess(
      summary: "Inconclusive / Mixed indicators",
      probability: 50,
      confidence: confLow,
      evidence: osClues
    )


proc guessPortAlias(port: int): string =
  if port in 8000..8099: return "Unknown (Likely HTTP)"
  if port in 8443..8449: return "Unknown (Likely HTTPS)"
  if port in 3307..3309: return "Unknown (Likely MySQL)"
  if port in 5433..5435: return "Unknown (Likely PostgreSQL)"
  if port in 6380..6389: return "Unknown (Likely Redis)"
  if port in 27017..27020: return "Unknown (Likely MongoDB)"
  if port >= 6000 and port <= 6063: return "Unknown (Likely X11)"
  return "Unknown"

proc getPortAlias(port: int): string =
  case port
  of 21, 2121: "FTP"
  of 22:       "SSH"
  of 23:       "Telnet"
  of 25:       "SMTP"
  of 53:       "DNS"
  of 80, 8080, 8180: "HTTP"
  of 111:      "RPCbind"
  of 135, 139, 445: "SMB/RPC"
  of 143, 993: "IMAP"
  of 443, 8443: "HTTPS"
  of 512..514: "r-services"
  of 1099:     "Java RMI"
  of 1524:     "Ingreslock Shell"
  of 2049:     "NFS"
  of 3306, 5432, 1433: "SQL Database"
  of 3389:     "RDP"
  of 3632:     "distccd"
  of 5900:     "VNC"
  of 6000:     "X11"
  of 6200:     "vsftpd Backdoor"
  of 6667:     "IRC"
  of 6697:     "IRC (SSL)"
  of 8787:     "Ruby DRb"
  else:        guessPortAlias(port)

proc fingerprintService(banner: string): string =
  let b = banner.toLowerAscii()
  if "ssh-" in b: return "SSH"
  if "220" in b and ("ftp" in b or "filezilla" in b or "vsftpd" in b): return "FTP"
  if "http/1." in b or "server:" in b: return "HTTP"
  if "mysql" in b or "mariadb" in b or "caching_sha2" in b: return "MySQL"
  if "esmtp" in b or "smtp" in b: return "SMTP"
  if "redis" in b: return "Redis"
  return ""

proc grabBanner(s: AsyncSocket): Future[string] {.async.} =
  try:
    await sleepAsync(400)
    let bannerFut = s.recv(1024)
    if await withTimeout(bannerFut, 1000):
      return bannerFut.read().strip()
  except:
    discard
  return ""


proc checkPort(ip: string, port: Port, timeout: int): Future[string] {.async.} =
  var client: AsyncSocket
  try:
    client = newAsyncSocket()
  except OSError:
    return mFail & " OS Error creating socket for port " & $port.int

  try:
    var connectFuture = client.connect(ip, port)
    if await withTimeout(connectFuture, timeout):
      if not connectFuture.failed:
        recordPortForOS(port.int)

        var alias = getPortAlias(port.int)
        var rawBanner = ""
        var extraInfo = ""

        if conf.grabBanners:
          let speakFirst = [21, 22, 23, 25, 110, 143, 993, 995, 2121, 5900, 6667, 1524, 6200]

          if port.int in speakFirst:
            rawBanner = await grabBanner(client)
          elif "HTTP" in alias:
            await client.send("HEAD / HTTP/1.0\r\n\r\n")
            rawBanner = await grabBanner(client)
          else:
            await client.send("\r\n\r\n")
            rawBanner = await grabBanner(client)

          if rawBanner.len > 0:
            analyzeBannerForOS(rawBanner)

            let trueService = fingerprintService(rawBanner)
            if trueService != "": alias = trueService

            if "HTTP" in alias and rawBanner.toLowerAscii().contains("server:"):
              for line in rawBanner.splitLines():
                if line.toLowerAscii().startsWith("server:"):
                  extraInfo = " [" & line.replace("Server:", "").replace("server:", "").strip() & "]"
                  break

        let portStr = align($port.int, 5)
        let aliasStr = alignLeft("(" & alias & ")", 26)
        var output = mSucc & " Port " & portStr & " " & aliasStr & " " & wOpen

        if extraInfo != "":
          output.add(extraInfo)
        elif rawBanner.len > 0:
          var clean = rawBanner.replace("\r", "").replace("\n", " ").strip()
          if clean.len > 50: clean = clean[0..47] & "..."
          output.add(" | " & clean)

        return output
  except:
    discard
  finally:
    safeClose(client)

  return ""


proc parseArguments() =
  var p = initOptParser()
  for kind, key, val in p.getopt():
    case kind
    of cmdArgument:
      if conf.target == "": conf.target = key
    of cmdLongOption, cmdShortOption:
      case key
      of "p", "ports":
        if val.contains("-"):
          let parts = val.split("-")
          conf.startPort = parseInt(parts[0])
          conf.endPort = parseInt(parts[1])
        else:
          conf.startPort = parseInt(val)
          conf.endPort = parseInt(val)
      of "t", "timeout":
        conf.timeout = parseInt(val)
      of "b", "batch":
        conf.batchSize = parseInt(val)
      of "o", "output":
        conf.outputFile = val
      of "nobanner":
        conf.grabBanners = false
      of "h", "help":
        echo "Usage: nimmap <IP> [options]"
        echo "Options:"
        echo "  -p, --ports:START-END   Range of ports"
        echo "  -t, --timeout:MS        Timeout in ms"
        echo "  -b, --batch:SIZE        Batch size (default 300)"
        echo "  -o, --output:FILE       Save results to a file"
        echo "  --nobanner              Disable banner grabbing"
        echo "Example: nimmap 192.168.10.162 -p:1-10000 -o:results.txt"
        quit(0)
    of cmdEnd: discard

  if conf.target == "":
    echo "Usage: nimmap <IP> [options]"
    quit(0)

proc printLogo() =
  let logo = cLime & """
    _   _  _
   | \ | |(_)
   |  \| | _  _ __ ___   _ __ ___    __ _  _ __
   | . ` || || '_ ` _ \ | '_ ` _ \  / _` || '_ \
   | |\  || || | | | | || | | | | || (_| || |_) |
   |_| \_||_||_| |_| |_||_| |_| |_| \__,_|| .__/
                                          | |
          >> LIGHTWEIGHT ASYNC SCANNER << |_|
            >> by Jørn E.Jenssen <<
  """ & cReset
  echo logo

proc main() {.async.} =
  printLogo()
  parseArguments()

  echo "Target: " & conf.target & " (" & $conf.startPort & "-" & $conf.endPort & ")"
  if conf.outputFile != "": echo "Output: " & conf.outputFile
  echo ""

  var
    batch: seq[Future[string]] = @[]
    currentPort = conf.startPort
    allFoundPorts: seq[string] = @[]

  while currentPort <= conf.endPort:
    while batch.len < conf.batchSize and currentPort <= conf.endPort:
      batch.add(checkPort(conf.target, Port(currentPort), conf.timeout))
      currentPort.inc()

    let batchResults = await all(batch)
    batch = @[]

    for result in batchResults:
      if result != "":
        allFoundPorts.add(result)
        stdout.write("\r" & " ".repeat(70) & "\r")
        echo result

    let percent = ((currentPort - 1 - conf.startPort) * 100 div (conf.endPort - conf.startPort + 1))
    stdout.write("[*] Progress: " & $percent & "%\r")
    stdout.flushFile()

  stdout.write("\r" & " ".repeat(70) & "\r")
  echo mScan & " Scan Complete.\n"

  let osGuess = deduceOS()
  echo "--- Target OS Intelligence ---"
  echo "Prediction:    ", osGuess.summary
  echo "Probability:   ~", osGuess.probability, "%"
  echo "Confidence:    ", $osGuess.confidence
  echo "KEEP IN MIND:  Banner signatures reflect advertised daemon strings and can be spoofed."
  if osGuess.evidence.len > 0:
    echo "Evidence:"
    for item in osGuess.evidence:
      echo mEvid & " ", item
  echo "------------------------------\n"

  if conf.outputFile != "":
    try:
      var fileContent = "Scan Results for " & conf.target & "\n"
      fileContent &= strutils.repeat('=', 40) & "\n"
      for line in allFoundPorts:
        fileContent &= stripAnsi(line) & "\n"

      fileContent &= "\n--- Target OS Intelligence ---\n"
      fileContent &= "Prediction:    " & osGuess.summary & "\n"
      fileContent &= "Probability:   ~" & $osGuess.probability & "%\n"
      fileContent &= "Confidence:    " & $osGuess.confidence & "\n"
      fileContent &= "KEEP IN MIND:  Banner signatures reflect advertised daemon strings and can be spoofed.\n"
      for item in osGuess.evidence:
        fileContent &= "[E] " & item & "\n"

      writeFile(conf.outputFile, fileContent)
      echo mScan & " Results saved successfully to ", conf.outputFile
    except IOError:
      echo mFail & " Failed to write to output file."

when isMainModule:
  waitFor main()
