Buffer = require('buffer').Buffer
Conditions = require('./conditions')

strStartsWith = (str, prefix) ->
  str.substr(0, prefix.length) == prefix

module.exports = exports =
  'AutoProxy':
    magicPrefix: 'W0F1dG9Qcm94' # Detect base-64 encoded "[AutoProxy".
    detect: (text) ->
      if strStartsWith(text, exports['AutoProxy'].magicPrefix)
        return true
      else if strStartsWith(text, '[AutoProxy')
        return true
      return
    preprocess: (text) ->
      text = text.trim()
      if strStartsWith(text, exports['AutoProxy'].magicPrefix)
        text = new Buffer(text, 'base64').toString('utf8')
      return text
    parse: (text, matchProfileName, defaultProfileName) ->
      text = text.trim()
      normal_rules = []
      exclusive_rules = []
      for line in text.split(/\n|\r/)
        line = line.trim()
        continue if line.length == 0 || line[0] == '!' || line[0] == '['
        source = line
        profile = matchProfileName
        list = normal_rules
        if line[0] == '@' and line[1] == '@'
          profile = defaultProfileName
          list = exclusive_rules
          line = line.substring(2)
        cond =
          if line[0] == '/'
            conditionType: 'UrlRegexCondition'
            pattern: line.substring(1, line.length - 1)
          else if line[0] == '|'
            if line[1] == '|'
              conditionType: 'HostWildcardCondition'
              pattern: "*." + line.substring(2)
            else
              conditionType: 'UrlWildcardCondition'
              pattern: line.substring(1) + "*"
          else if line.indexOf('*') < 0
            conditionType: 'KeywordCondition'
            pattern: line
          else
            conditionType: 'UrlWildcardCondition'
            pattern: 'http://*' + line + '*'
        list.push({condition: cond, profileName: profile, source: source})
      # Exclusive rules have higher priority, so they come first.
      return exclusive_rules.concat normal_rules
  'Switchy':
    conditionFromLegacyWildcard: (pattern) ->
      if pattern[0] == '@'
        pattern = pattern.substring(1)
      else
        if pattern.indexOf('://') <= 0 and pattern[0] != '*'
          pattern = '*' + pattern
        if pattern[pattern.length - 1] != '*'
          pattern += '*'

      host = Conditions.urlWildcard2HostWildcard(pattern)
      if host
        conditionType: 'HostWildcardCondition'
        pattern: host
      else
        conditionType: 'UrlWildcardCondition'
        pattern: pattern

    parse: (text, matchProfileName, defaultProfileName) ->
      text = text.trim()
      normal_rules = []
      exclusive_rules = []
      begin = false
      section = 'WILDCARD'
      for line in text.split(/\n|\r/)
        line = line.trim()
        continue if line.length == 0 || line[0] == ';'
        if not begin
          if line.toUpperCase() == '#BEGIN'
            begin = true
          continue
        if line.toUpperCase() == '#END'
          break
        if line[0] == '[' and line[line.length - 1] == ']'
          section = line.substring(1, line.length - 1).toUpperCase()
          continue
        source = line
        profile = matchProfileName
        list = normal_rules
        if line[0] == '!'
          profile = defaultProfileName
          list = exclusive_rules
          line = line.substring(1)
        cond = switch section
          when 'WILDCARD'
            exports['Switchy'].conditionFromLegacyWildcard(line)
          when 'REGEXP'
            conditionType: 'UrlRegexCondition'
            pattern: line
          else
            null
        if cond?
          list.push({condition: cond, profileName: profile, source: source})
      # Exclusive rules have higher priority, so they come first.
      return exclusive_rules.concat normal_rules
