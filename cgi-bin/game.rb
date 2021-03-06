#!/usr/bin/env ruby
# Copyright Maria Pacana 2013. All rights reserved.

$nfs = false

require "rubygems" if $nfs
require "cgi"
require "erb"
require "json"
require "net/http"
require "sqlite3"
require "time"
require "uri"

=begin
drop table if exists games;
drop table if exists gamestoplayers;
drop table if exists pics;
drop table if exists players;
drop table if exists sentences;

CREATE TABLE games (gameid integer primary key, turn integer, active boolean);
CREATE TABLE gamestoplayers (gameid integer, playerid integer, turn integer, active boolean, token integer, time integer);
CREATE TABLE pics (picid integer primary key, data blob, gameid integer, turn integer);
CREATE TABLE players (playerid integer primary key, email varchar(255), optedout boolean, optout_token integer);
CREATE TABLE sentences (sentenceid integer primary key, sentence blob, gameid integer, turn integer);
CREATE INDEX gameid_g ON games (gameid);
CREATE INDEX gameid_gtp ON gamestoplayers (gameid);
CREATE INDEX gameid_p ON pics (gameid);
CREATE INDEX gameid_s ON sentences (gameid);
=end

$really_send_email = false
$standard_email = "info@grapevine-game.com"
$sendmail = "/usr/bin/sendmail"
$cgi = CGI.new
$params = $cgi.params

if $nfs
  DB_FILENAME = "../data/picdata.db"
  $template_path = "templates/"
  $page_path = "http://www.grapevine-game.com/cgi-bin/"
else
  DB_FILENAME = "data/picdata.db"
  $template_path = "cgi-bin/templates/"
  $page_path = "http://localhost:8000/cgi-bin/"
end

# Outputs a response as a JSON object.
# 'success' is true or false.
# 'message' is a string containing additional details.
def send_response(success, message)
  $cgi.out("text/plain") do
    { "success" => success,
      "message" => message,
    }.to_json
  end  # Converts hash to JSON.
end

# Creates a new game.
def create_game(data, email, sentence, time)
  db = SQLite3::Database.new(DB_FILENAME)
  turn = 1
  
  # Adds a new game to the games table.
  db.execute("insert into games (turn, active) values (?, ?)", [turn, 1])
  gameid = db.last_insert_row_id().to_i

  # Adds first player's moves into the pics and sentences tables.
  db.transaction do |db|
    db.execute("insert into pics (data, gameid, turn) values (?, ?, ?)", [data, gameid, turn]) 
    db.execute("insert into sentences (sentence, gameid, turn) values (?, ?, ?)", [sentence, gameid, turn]) 	
  end 

  # Adds information for new players into players table.
  # For the first player, inserts player information, including time of turn, into gamestoplayers. 
  # Otherwise, inserts player information, without time of turn, into gamestoplayers.
  for e in email do  
    token = rand(2**31)
    r = db.execute("select playerid from players where email = ?",e)

    if !r.empty?
      playerid = r[0][0].to_i
    else
      optout_token = rand(2**31)
      db.execute("insert into players (email, optedout, optout_token) values (?, 0, ?)", [e, optout_token])
      playerid = db.last_insert_row_id().to_i
    end

    # Inserts player information if (1) it's player's first turn and (2) players are not opted out.
    optedout = db.execute("select optedout from players where email = ?",e)[0][0].to_i
    if turn == 1
      params = [gameid, playerid, turn, token, time]
      db.execute("insert into gamestoplayers (gameid, playerid, turn, active, token, time) values (?, ?, ?, 1, ?, ?)", params) 
      turn +=1
    else
      if optedout == 0
        params = [gameid, playerid, turn, token]
        db.execute("insert into gamestoplayers (gameid, playerid, turn, active, token, time) values (?, ?, ?, 1, ?, 0)", params) 
        turn +=1
      end
    end
  end
  gameid
end

# Displays all of the turns of a game in a single page.
def displayall(gameid, token)
  db = SQLite3::Database.new(DB_FILENAME)
  maxturns = db.execute("select max(turn) from gamestoplayers where gameid=?", gameid)[0][0].to_i
  last_played = db.execute("select time from gamestoplayers where gameid=? and turn = ?", [gameid, maxturns])[0][0].to_i
  correct_token = db.execute("select token from gamestoplayers where gameid = ? and turn = 1", gameid)[0][0].to_i

  if (token == correct_token) && (last_played > 0) 
    turndata = []
    
    # Gets all player data (turn #, emails, sentences, etc) for a particular game.
    turndata = db.execute("SELECT gtp.turn, pl.email, pi.data, s.sentence
      FROM gamestoplayers gtp INNER JOIN players pl ON(gtp.playerid = pl.playerid)
      LEFT JOIN pics pi ON(gtp.gameid = pi.gameid AND gtp.turn = pi.turn)
      LEFT JOIN sentences s ON(gtp.gameid = s.gameid AND gtp.turn = s.turn)
      WHERE gtp.gameid = ?
      AND gtp.turn > 0
      ORDER BY gtp.turn ASC", gameid) 
    template_data = IO.read($template_path + 'displayall.html.erb')
    template = ERB.new(template_data)
  else
    template_data = IO.read($template_path + 'wrongtoken.html.erb')
    template = ERB.new(template_data)
  end
  $cgi.out() { template.result(binding) }
end

# Shows a previous player's turn to the current player.
def show(gameid,turn,token)
  db = SQLite3::Database.new(DB_FILENAME)
  correct_token = db.execute("select token from gamestoplayers where gameid = ? and turn = ?", [gameid, turn])[0][0].to_i

  if (token == correct_token)
    # Shows sentences
    if turn.even? 
      sentence = db.execute("select sentence from sentences where gameid = ? and turn = ?", [gameid, turn-1])[0][0]
      template_data = IO.read($template_path +'senturn.html.erb')
      template = ERB.new(template_data)
    # Shows pics
    else 
      picdata = db.execute("select data from pics where gameid = ? and turn = ?", [gameid, turn-1])[0][0]
      template_data = IO.read($template_path + 'picturn.html.erb')
      template = ERB.new(template_data)
    end
  else
    template_data = IO.read($template_path + 'wrongtoken.html.erb')
    template = ERB.new(template_data)
  end
  $cgi.out() { template.result(binding) }
end

# Sends email to the next player containing a link to the previous turn's data.
def send_email(gameid,turn)
  db = SQLite3::Database.new(DB_FILENAME)
  maxturns = db.execute("select max(turn) from gamestoplayers where gameid=?", gameid)[0][0].to_i
  email_message = ''

  # Looks up game and turn to find next player and turn type.
  # Loads appropriate template and fills in blanks.
  # There are 3 types of template (pic, sentence, final).
  if (turn == maxturns + 1) 
    player_emails = []
    player_ids = db.execute("select playerid from gamestoplayers where gameid = ? and active = 1", gameid)
    player_ids.each {|i| player_emails << db.execute("select email from players where playerid = ?", i[0].to_i)[0][0] }
    token = db.execute("select token from gamestoplayers where gameid = ? and turn = 1", gameid)[0][0].to_i

    template_data = IO.read($template_path + 'displayallemail.txt.erb')
    template = ERB.new(template_data)
    email_message = template.result(binding)
  else
    current_playerid = db.execute("select playerid from gamestoplayers where gameid = ? and turn = ?", [gameid, turn-1])[0][0].to_i
    next_playerid = db.execute("select playerid from gamestoplayers where gameid = ? and turn = ?", [gameid, turn])[0][0].to_i
    current_email = db.execute("select email from players where playerid = ?", current_playerid)[0][0]
    next_email = db.execute("select email from players where playerid = ?", next_playerid)[0][0]
    next_optout_token = db.execute("select optout_token from players where playerid = ?", next_playerid)[0][0].to_i
    current_token = db.execute("select token from gamestoplayers where gameid = ? and turn = ?", [gameid, turn])[0][0].to_i
    if turn.odd?
	    template_data = IO.read($template_path + 'senturnemail.txt.erb')
    else
	    template_data = IO.read($template_path + 'picturnemail.txt.erb')
    end
    template = ERB.new(template_data)
    email_message = template.result(binding)
  end
  
  # Sends the email.
  # - If maximum number of turns, step through all the emails.
  if $really_send_email
    if (turn == maxturns + 1)
      player_emails.each do |i|
        IO.popen("#{$sendmail} #{i}", 'w') do |file|
          file.puts email_message
        end
      end
    else
      IO.popen("#{$sendmail} #{next_email}", 'w') do |file|
        file.puts email_message
      end
    end
  else
    File.open('sentemail.txt', 'w') do |file|
      file.puts email_message
    end
  end
end

# Saves sentence data in odd-numbered turns.
def savesentence(sentence,gameid,turn,time)
  db = SQLite3::Database.new(DB_FILENAME)

  if (db.execute("select sentence from sentences where gameid = ? and turn = ?", [gameid, turn])[0] == nil) 
    db.transaction do |db|
      db.execute("insert into sentences (sentence, gameid, turn) values (?,?,?)", [sentence, gameid, turn]) 
      db.execute("update gamestoplayers set time = ? where gameid = ? and turn = ?", [time, gameid, turn])
      db.execute("update games set turn = ? where gameid = gameid", turn)
    end
    send_response(true, "Turn successfully submitted!")
  else
    send_response(false, "You've already played your turn.")
  end
end

# Saves pic data in even-numbered turns.
def savepic(data,gameid,turn,time)
  db = SQLite3::Database.new(DB_FILENAME)
  if (db.execute("select data from pics where gameid = ? and turn = ?", [gameid, turn])[0] == nil) 
    db.transaction do |db|
      db.execute("insert into pics (data, gameid, turn) values (?,?,?)", [data, gameid, turn]) 
      db.execute("update gamestoplayers set time = ? where gameid = ? and turn = ?",[time, gameid, turn])
      db.execute("update games set turn = ? where gameid = gameid", turn)
    end
    send_response(true, "Turn successfully submitted!")
  else
    send_response(false, "You've already played your turn.")
  end
end

# This function makes inactive all turns of games that a player is involved in, and skips to the next player.
# It sets optedout for each player to 1.
def optout(playerid, optout_token)
  db = SQLite3::Database.new(DB_FILENAME)

  games = db.execute("select gameid from gamestoplayers where playerid = ? and time = ? and active = ?", [playerid, 0, 1]).flatten.uniq.map {|g| g.to_i }
  db.execute("update players set optedout = 1 where playerid = ? and optout_token = ?", [playerid, optout_token])
  
  gamesturns = [] 
  
  for gameid in games
    turn = nil
    db.transaction do |db|
      turn = db.execute("select turn from gamestoplayers where gameid = ? and playerid = ? and time = ?", [gameid, playerid, 0])[0][0].to_i
      db.execute("update gamestoplayers set active = 0 where gameid = ? and playerid = ? and time = ?", [gameid, playerid, 0])
      db.execute("update gamestoplayers set turn = 0 where gameid = ? and playerid = ? and time = ?", [gameid, playerid, 0])
      db.execute("update gamestoplayers set turn = turn - 1 where gameid = ? and turn > ?", [gameid, turn])
     
    gamesturns << "[" + gameid.to_s + "," + turn.to_s + "]" # For debugging.
    end
    send_email(gameid, turn)     
  end
  
  template_data = IO.read($template_path + 'optedout.html.erb')
  template = ERB.new(template_data)
  $cgi.out() { template.result(binding) }
end

def email_address_valid?(address)
  address =~ /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/i
end

def main
  if ($params["cmd"].empty?)
    error("missing cmd")
  end
    cmd = $params["cmd"][0]

  if (cmd == "create") # Creates a new game
    data = URI.unescape($params["data"][0]).to_s 
    sentence = URI.unescape($params["sentence"][0])
    email = URI.unescape($params["email"][0])
    challenge = $params["challenge"][0]
    response = $params["response"][0]
    time = Time.now.to_i

    form_data = {
    "privatekey" => "6Le9XNYSAAAAAETyJO4uJYxZTjXfopX6wenL9acR",
    "remoteip" => ENV['REMOTE_ADDR'],
    "challenge" => URI.escape(challenge),
    "response" => URI.escape(response),
    }

    # Verifies that the Recaptcha solution is accurate
    uri = URI.parse("http://www.google.com/recaptcha/api/verify")
    r = Net::HTTP.post_form(uri, form_data)

    # If returns HTTP error code, sends status in reply as a JSON object
    if r.code != '200' 			
      send_response(false, "Recaptcha request returned code #{r.code}.")
      return
    end

    lines = r.body.split("\n")
    if lines[0] != "true"
      message = case lines[1] 
        when "incorrect-captcha-sol" then "Invalid CAPTCHA answer; try again."
        else "Recaptcha returned an error (#{lines[1]})."
      end
      send_response(false, message)
      return
    else
      if (email.include? ",") 
        email = email.split(",")
      else
        email = email.split(" ")
      end				
      email.each {|e| e.strip! }
      if email.find {|e| !email_address_valid?(e) }
        send_response(false, "Invalid email address #{e}.")
        return
      end

      gameid = create_game(data, email, sentence, time)	
      send_email(gameid, 2)
      send_response(true, "Game successfully created!")
    end	
  elsif (cmd == "show") # Shows the current turn, but only to someone who has the token!
    gameid = $params["gameid"][0]
    turn = $params["turn"][0].to_i
    token = $params["token"][0].to_i
    show(gameid, turn, token) 
  elsif (cmd == "displayall") # Shows all turns
    gameid = $params["gameid"][0]
    token = $params["token"][0].to_i
    displayall(gameid, token) 
  elsif (cmd == "sentence") # Updates database with a sentence
    sentence = URI.unescape($params["sentence"][0]).to_s
    gameid = $params["gameid"][0]
    turn = $params["turn"][0].to_i
    time = Time.now.to_i
    savesentence(sentence, gameid, turn, time)
    send_email(gameid, turn+1)
  elsif (cmd == "pic") # Updates database with a picture
    data = URI.unescape($params["data"][0]).to_s
    gameid = $params["gameid"][0]
    turn = $params["turn"][0].to_i
    time = Time.now.to_i
    savepic(data, gameid, turn, time)
    send_email(gameid, turn+1)
  elsif (cmd == "optout") # Removes player from all games they are associated with.
    playerid = $params["playerid"][0].to_i
    optout_token = $params["optout_token"][0].to_i
    optout(playerid, optout_token)
  end
end

main
