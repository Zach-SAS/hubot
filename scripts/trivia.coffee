# Description
#   Trivia
# Commands:
#   hubot trivia question
#   hubot trivia answer

fuzzy = require('fuzzy-matching')
numtowords = require('number-to-words')
wordstonum = require('words-to-numbers')
continuous = true

pruneAnswer = (answer) ->
  out = [answer]
  # Remove any a/an/the/or
  article_answer = answer.replace(/\b(a|an|the)\b\s+/gi, '')
  if article_answer != answer
    out.push(article_answer)
  # Remove punctuation
  punc_answer = answer.replace(/(\.|,|&|!)/g, '')
  if punc_answer != answer
    out.push(article_answer)
  # Convert any numbers to word form
  if answer.match(/^\d+$/)
    out.push(numtowords.toWords(answer))
  # Convert any word numbers into actual numbers
  numword_answer = wordstonum.wordsToNumbers(answer)
  if numword_answer != answer
    out.push(numword_answer)
  decade_answer = answer.match(/^19(\d{2})s?$/)
  if decade_answer != null
    d = decade_answer[1]
    out.push("#{d}")
    out.push("#{d}s")
  return out

module.exports = (robot) ->
  all_questions = () -> robot.brain.data.questions ?= {}

  askQuestion = (msg) ->
    room = getCurrentRoom(msg)
    # This random IP is from http://www.randomtriviagenerator.com/#/
    robot.http('https://opentdb.com/api.php?amount=1&type=multiple&encode=url3986').get() (err, res, body) ->
      d = JSON.parse(body).results[0]
      question = decodeURIComponent(d.question)
      category = decodeURIComponent(d.category)
      difficulty = d.difficulty
      answer = decodeURIComponent(d.correct_answer)
      choices = d.incorrect_answers
      choices.push(answer)
      choices.sort(() -> Math.random() - 0.5)
      for i in [0...choices.length]
        s = choices.shift()
        choices.push(decodeURIComponent(s))
      fuzzy_answer = pruneAnswer(answer)
      answer_match = new fuzzy(fuzzy_answer)
      all_questions()[room] = {
        question: question
        answer: answer
        match: answer_match
        possible: fuzzy_answer
        choices: choices
      }
      robot.logger.info('Possible answers:', fuzzy_answer.join(', '))
      msg.send "[#{category} - #{difficulty}] #{question}"

  answerQuestion = (correct, msg) ->
    room = getCurrentRoom(msg)
    room_question = all_questions()[room]
    if room_question == undefined || room_question.answer == null
      msg.send "Ask a question first"
      return
    if correct
      correctStr = "Correct!! "
    else
      correctStr = ""
    msg.send "#{correctStr}#{room_question.question} -- #{room_question.answer}"
    delete all_questions()[room]
    if continuous
      askQuestion(msg)

  getCurrentRoom = (msg) ->
    if 'envelope' in msg
      return msg.envelope.room
    else
      return 'shell'

  robot.respond /trivia question/, (msg) ->
    askQuestion(msg)

  robot.respond /trivia answer/, (msg) ->
    answerQuestion(false, msg)
  
  robot.respond /trivia hint/, (msg) ->
    room = getCurrentRoom(msg)
    room_question = all_questions()[room]
    hint = room_question.choices.join('\n')
    msg.send hint

  robot.hear /(.+)/, (msg) ->
    room = getCurrentRoom(msg)
    room_question = all_questions()[room]
    if room_question != undefined
      s = msg.match[1].trim()
      r = room_question.match.get(s)
      robot.logger.info(room_question.answer, s, r)
      if r.distance > 0.85
        answerQuestion(true, msg)

  robot.respond /fuck.+question/, (msg) ->
    msg.send "Sorry :("
    answerQuestion(false, msg)
