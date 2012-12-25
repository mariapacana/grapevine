#!/usr/bin/env ruby
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

CREATE TABLE games (gameid integer primary key, turn integer);
CREATE TABLE gamestoplayers (gameid integer, playerid integer, turn integer, token integer, time integer);
CREATE TABLE pics (picid integer primary key, data blob, gameid integer, turn integer);
CREATE TABLE players (playerid integer primary key, email varchar(255), optedout integer);
CREATE TABLE sentences (sentenceid integer primary key, sentence blob, gameid integer, turn integer);
CREATE INDEX gameid_g ON games (gameid);
CREATE INDEX gameid_gtp ON gamestoplayers (gameid);
CREATE INDEX gameid_p ON pics (gameid);
CREATE INDEX gameid_s ON sentences (gameid);
=end

$cgi = CGI.new
$params = $cgi.params
DB_FILENAME = "picdata.db"

def error(message) # broken; sends 200 rather than 400
  $cgi.out({"Status" => "400 Bad Request"}) { message }
  exit
end

# Outputs a response as a JSON object.
# 'success' is true or false.
# 'message' is a string containing additional details.
def send_response(success, message)
  $cgi.out("text/plain") { {"success" => success, "message" => message}.to_json } # Converts hash to JSON.
end

# Creates a new game.
def create_game(data, email, sentence, time)
  db = SQLite3::Database.new(DB_FILENAME)
  turn = 1
  optedout = 0

  db.execute("insert into games (turn) values (?)", turn)
  gameid = db.last_insert_row_id().to_i

  db.transaction do |db|
    db.execute("insert into pics (data, gameid, turn) values (?,?,?)", [data, gameid, turn]) 
    db.execute("insert into sentences (sentence, gameid, turn) values (?,?,?)", [sentence, gameid, turn]) 	
  end 

  for e in email do
    playerid = nil
    r = db.execute("select playerid from players where email = ?",e)

    if !r.empty?
      playerid = r[0][0]
    else
      db.execute("insert into players (email, optedout) values (?,?)", [e,optedout])
      playerid = db.last_insert_row_id().to_i
    end

    token = rand(2**31)
    if (turn == 1) then
      params = [gameid, playerid, turn, token, time]
      db.execute("insert into gamestoplayers (gameid, playerid, turn, token, time) values (?,?,?,?,?)", params) 
    else
      params = [gameid, playerid, turn, token]
      db.execute("insert into gamestoplayers (gameid, playerid, turn, token) values (?,?,?,?)", params) 
    end
    turn += 1
  end
  gameid
end

def displayall(gameid,turn,token)

  db = SQLite3::Database.new(DB_FILENAME)
  maxturns = db.execute("select count(*) from gamestoplayers where gameid=?",gameid)[0][0]
  correct_token = db.execute("select token from gamestoplayers where gameid = ? and turn = ?", [gameid,turn])[0][0]

  if (token == correct_token) && (turn == maxturns) 
    turndata = []
    
    #Gets an array of arrays. Still don't understand left join. 
    #IFNULL(s.sentence, pi.data) doesn't work because of first player.
    turndata = db.execute("SELECT gtp.turn, pl.email, pi.data, s.sentence
      FROM gamestoplayers gtp INNER JOIN players pl ON(gtp.playerid = pl.playerid)
      LEFT JOIN pics pi ON(gtp.gameid = pi.gameid AND gtp.turn = pi.turn)
      LEFT JOIN sentences s ON(gtp.gameid = s.gameid AND gtp.turn = s.turn)
      WHERE gtp.gameid = ?
      ORDER BY gtp.turn ASC", gameid) 
    template_data = IO.read('cgi-bin/templates/displayall.html.erb')
    template = ERB.new(template_data)
  else
    template_data = IO.read('cgi-bin/templates/wrongtoken.html.erb')
    template = ERB.new(template_data)
  end
  $cgi.out() { template.result(binding) }
end

def show(gameid,turn,token)
  db = SQLite3::Database.new(DB_FILENAME)
  correct_token = db.execute("select token from gamestoplayers where gameid = ? and turn = ?", [gameid,turn])[0][0]

  if (token == correct_token)
    #shows sentences
    if turn.odd? #& turn < maxturns
      sentence = db.execute("select sentence from sentences where gameid = ? and turn = ?", [gameid,turn])[0][0]
      template_data = IO.read('cgi-bin/templates/senturn.html.erb')
      template = ERB.new(template_data)
    #shows pics
    else 
      picdata = db.execute("select data from pics where gameid = ? and turn = ?", [gameid,turn])[0][0]
      template_data = IO.read('cgi-bin/templates/picturn.html.erb')
      template = ERB.new(template_data)
    end
  else
    template_data = IO.read('cgi-bin/templates/wrongtoken.html.erb')
    template = ERB.new(template_data)
  end
  $cgi.out() { template.result(binding) }
end

def send_email(gameid,turn)
  db = SQLite3::Database.new(DB_FILENAME)
  maxturns = db.execute("select count(*) from gamestoplayers where gameid=?",gameid)[0][0]
  email_message = ''

  # Looks up game and turn to find next player and turn type.
  # Loads appropriate template and fills in blanks.
  # There are 3 types of template (pic, sentence, final).
  if (turn == maxturns) 
    player_emails = []
    player_ids = db.execute("select playerid from gamestoplayers where gameid = ?", gameid)
    player_ids.each {|i| player_emails << db.execute("select email from players where playerid = ?",i[0])[0][0] }
    token = db.execute("select token from gamestoplayers where gameid = ? and turn = ?", [gameid,turn])[0][0]

    template_data = IO.read('cgi-bin/templates/displayallemail.txt.erb')
    template = ERB.new(template_data)
    email_message = template.result(binding)
  else
    currentplayer_id = db.execute("select playerid from gamestoplayers where gameid = ? and turn = ?", [gameid,turn])[0][0]
    nextplayer_id = db.execute("select playerid from gamestoplayers where gameid = ? and turn = ?", [gameid,turn+1])[0][0]
    currentplayer_e = db.execute("select email from players where playerid = ?", currentplayer_id)[0][0]
    nextplayer_e = db.execute("select email from players where playerid = ?", nextplayer_id)[0][0]
    token = db.execute("select token from gamestoplayers where gameid = ? and turn = ?", [gameid,turn])[0][0]
    if turn.odd?
	    template_data = IO.read('cgi-bin/templates/senturnemail.txt.erb')
    else
	    template_data = IO.read('cgi-bin/templates/picturnemail.txt.erb')
    end
    template = ERB.new(template_data)
    email_message = template.result(binding)
  end
  
  File.open('sentemail.txt', 'w') do |file|
  file.puts email_message
  end
# create tmail message
end

def savesentence(sentence,gameid,turn,time)
  db = SQLite3::Database.new(DB_FILENAME)

  db.transaction do |db|
    db.execute("insert into sentences (sentence, gameid, turn) values (?,?,?)", [sentence, gameid, turn]) 
    db.execute("update gamestoplayers set time = ? where gameid = ? and turn = ?", [time, gameid, turn])
    db.execute("update games set turn=? where gameid=gameid", turn)
  end
end

def savepic(data,gameid,turn,time)
  db = SQLite3::Database.new(DB_FILENAME)

  db.transaction do |db|
    db.execute("insert into pics (data, gameid, turn) values (?,?,?)", [data, gameid, turn]) 
    db.execute("update gamestoplayers set time = ? where gameid = ? and turn = ?",[time, gameid, turn])
    db.execute("update games set turn=? where gameid=gameid", turn)
  end
end

def optout(playerid, token)
  db = SQLite3::Database.new(DB_FILENAME)
  
=begin
  current_turn = db.execute("select turn from gamestoplayers where playerid = ? and token = ?", [playerid, token])[0][0]
  gameid = db.execute("select gameid from gamestoplayers where playerid = ? and token = ?", [playerid, token])[0][0]
  
  db.transaction do |db|
    db.execute("update players set optedout = ? where playerid = ?", [1, playerid])
    db.execute("delete from gamestoplayers where playerid = ? and token = ?", [playerid, token])
    db.execute("update gamestoplayers set turn = turn - 1 where gameid = ? and turn = ?", [gameid, current_turn + 1])
  end
=end
  
  #ISSUE: Token not associated with current player, but the previous player!  
  template_data = IO.read('cgi-bin/templates/optedout.html.erb')
  template = ERB.new(template_data)
  $cgi.out() { template.result(binding) }
  
  send_email(gameid, current_turn) 

end

def main
  if ($params["cmd"].empty?)
    error("missing cmd")
  end
    cmd = $params["cmd"][0]

  if (cmd == "create") # Creates a new game
    data = URI.unescape($params["data"][0]).to_s # changes &&s for instance
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
      send_response(false, "http-" + r.code)
    return
    end

    lines = r.body.split("\n")
    if lines[0] != "true" 
      send_response(false, lines[1])
      return
    else
      if (email.include? ",") 
        email = email.split(",")
      else
        email = email.split(" ")
      end				
      email.each {|i| i.strip! }

      gameid = create_game(data, email, sentence, time)	
      send_email(gameid, 1)
      send_response(true, lines[1])
    end	
  elsif (cmd == "show") # Shows the current turn, but only to someone who has the token!
    gameid = $params["gameid"][0]
    turn = $params["turn"][0].to_i
    token = $params["token"][0].to_i
    show(gameid, turn, token) 
  elsif (cmd == "displayall") # Shows all turns
    gameid = $params["gameid"][0]
    turn = $params["turn"][0].to_i
    token = $params["token"][0].to_i
    displayall(gameid, turn, token) 
  elsif (cmd == "sentence") # Updates database with a sentence
    sentence = URI.unescape($params["sentence"][0]).to_s
    gameid = $params["gameid"][0]
    turn = $params["turn"][0].to_i+1
    time = Time.now.to_i
    savesentence(sentence, gameid, turn, time)
    send_email(gameid, turn)
  elsif (cmd == "pic") # Updates database with a picture
    data = URI.unescape($params["data"][0]).to_s
    gameid = $params["gameid"][0]
    turn = $params["turn"][0].to_i+1
    time = Time.now.to_i
    savepic(data, gameid, turn, time)
    send_email(gameid, turn)
  elsif (cmd == "optout") # Removes player from this game.
    playerid = $params["playerid"][0]
    token = $params["token"][0].to_i
    optout(playerid, token)
  end
end

main
