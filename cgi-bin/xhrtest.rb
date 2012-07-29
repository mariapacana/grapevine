#!/usr/bin/env ruby
require "cgi"
require "sqlite3"
require "uri"
require "json"
require "erb"

=begin
drop table if exists games;
drop table if exists gamestoplayers;
drop table if exists pics;
drop table if exists players;

CREATE TABLE games (gameid integer primary key, turn integer);
CREATE TABLE gamestoplayers (gameid integer, playerid integer, turn integer, token integer);
CREATE TABLE pics (picid integer primary key, data blob, gameid integer, turn integer);
CREATE TABLE players (playerid integer primary key, email varchar(255), optedout integer);
=end

$cgi = CGI.new
$params = $cgi.params

def error(message) #broken; sends 200 rather than 400
	$cgi.out({"Status" => "400 Bad Request"}) { message }
	exit
end

def makenewgame(data, email)
	db = SQLite3::Database.new("picdata.db")
	turn= 1
	optedout = 0
	
	db.execute("insert into games (turn) values (?)", turn)
	gameid = db.last_insert_row_id().to_i

	db.execute("insert into pics (data, gameid, turn) values (?,?,?)", [data, gameid, turn]) 
	
	for e in email do
		if db.execute("select * from players where email = ?",e).empty?
			db.execute("insert into players (email, optedout) values (?,?)", [e,optedout])
		end
	
		playerid = db.last_insert_row_id().to_i
		token = rand(10000)
		params = [gameid, playerid, turn, token]
		db.execute("insert into gamestoplayers (gameid, playerid, turn, token) values (?,?,?,?)", params) 
	end
end

def showturn(email,gameid)
	#retrieves picture from database
	db = SQLite3::Database.new("picdata.db")
	playerid = db.execute("select playerid from players where email = ?",email)[0][0]
	
	params = [gameid, playerid]
	turn = db.execute("select turn from gamestoplayers where gameid = ? and playerid = ?", params)[0][0]
	
	params = [gameid, turn]
	picdata = db.execute("select data from pics where gameid = ? and turn = ?", params)[0][0]
	
	#shows picture via the erb template
	template_data = IO.read('cgi-bin/templates/picturn.html.erb')
  template = ERB.new(template_data)
  
  #need to actually show the template. : /
  $cgi.out() { template.result(binding) }
end

def main
	# cmd is 'new', 'showturn', 'playturn', 'view'
	email=[]
	
  if ($params["cmd"].empty?)
    error("missing cmd")
  end
  
	cmd = $params["cmd"][0]
	if (cmd == "new") 
		data = URI.unescape($params["data"][0]).to_s #changes &&s for instance
		email = $params["email"][0].split(",")
		for i in email do i.strip! end
		makenewgame(data, email)	
	elsif (cmd == "showturn") 
		showturn(email,gameid)
	elsif (cmd == "playturn") 
		error("you haven't made this yet")
	else 
		error("or this")
	end
end

#main
showturn("maria",1)

=begin
cgi.out() do 
	{ 'img' => data, 'arg2' => "kittens"}.to_json
end
=end

