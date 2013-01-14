#!/usr/bin/env ruby
# Copyright Maria Pacana 2013. All rights reserved.

require "cgi"
require "erb"
require "json"
require "net/http"
require "sqlite3"
require "time"
require "uri"

require "/cgi-bin/game.rb"

DB_FILENAME = "picdata.db"

def main

  db = SQLite3::Database.new(DB_FILENAME)
  
  # Find all games where it has been over a week since the last turn was played.
  # - Find all unfinished games.
  
  # Skip over the current player and move to the next player, or finish the game.
  
  
  
  
  # find games
  active_games = db.execute("SELECT gameid 
    FROM gamestoplayers gtp INNER JOIN 
  
  turndata = db.execute("SELECT gtp.turn, pl.email, pi.data, s.sentence
    FROM gamestoplayers gtp INNER JOIN players pl ON(gtp.playerid = pl.playerid)
    LEFT JOIN pics pi ON(gtp.gameid = pi.gameid AND gtp.turn = pi.turn)
    LEFT JOIN sentences s ON(gtp.gameid = s.gameid AND gtp.turn = s.turn)
    WHERE gtp.gameid = ?
    AND gtp.turn > 0
    ORDER BY gtp.turn ASC", gameid) 
      

  games = db.execute("select gameid from gamestoplayers where playerid = ? and time = ?", [playerid, 0]).flatten
  
  # update database
  for gameid in games
    turn = nil
    db.transaction do |db|
      turn = db.execute("select turn from gamestoplayers where gameid = ? and playerid = ? and time = ?", [gameid, playerid, 0])[0][0]
      db.execute("update gamestoplayers set active = 0 where gameid = ? and playerid = ? and time = ?", [gameid, playerid, 0])
      db.execute("update gamestoplayers set turn = 0 where gameid = ? and playerid = ? and time = ?", [gameid, playerid, 0])
      db.execute("update gamestoplayers set turn = turn - 1 where gameid = ? and turn > ?", [gameid, turn])
      
      gamesturns << "[" + gameid.to_s + "," + turn.to_s + "]" # For debugging.
    end
    send_email(gameid, turn)     
  end
end

