var can;
var ctx;
var canX;
var canY;
var canDraw = false;
var started = false;

function draw() {
	can = $("myCanvas"); 
	form = $("form");
	picture = document.getElementsByClassName("picture");
	status = $("status");
    
	ctx = can.getContext("2d");
	can.addEventListener("mousedown", mousedown, false);
	can.addEventListener("mouseup", mouseup, false);
};

function mousedown(e) {
	canDraw = true;
	can.addEventListener("mousemove", mousemove, false);
};

function mouseup(e) {
	canDraw = false;
};

function mousemove(e) {
	if (!e) var e = event;
		canX = e.pageX - can.offsetLeft;
    canY = e.pageY - can.offsetTop;
  if (canDraw && !started) {
    ctx.beginPath();
    ctx.moveTo(canX, canY);
    started = true;
	} else if (canDraw && started) {
    ctx.lineTo(canX, canY);
    ctx.stroke();
  } else {
  canDraw = false;
  started = false;
  }
};


function getparams() {
	var url = window.location.search.substring(1).split("&");
	var params = {};
	
	for (var i = 0; i < url.length; i++) {
		var parts = url[i].split("="); 
		params[parts[0]]=parts[1];
	}
	
	return params;
	
};

function submitfirstpic(e) {
  var img = can.toDataURL("image/png");
  var email = $("email").value.trim();
  if (email.length == 0) {
    $("status").innerText = "Please enter valid email addresses.";
    return;
  }
  
  sendRequest("/cgi-bin/game.rb", "POST", "cmd=new&data=" + encodeURIComponent(img) + "&email="+$("email").value,
   	function(response) {
   		 $("status").innerText = "Game started!";
   	});
};

function submitsentence() {
	var params = getparams();
	var url = "cmd=sentence&sentence="+$("sentence").value+"&gameid="+params.gameid+"&turn="+params.turn;
	
  sendRequest(
  	"/cgi-bin/game.rb", "POST", url,
  	function(response) {
  	  $("status").innerText = "Sentence sent!";
   	});
};

function submitpic() {
  var img = can.toDataURL("image/png");
  var params = getparams();
  var url = "cmd=pic&data=" + encodeURIComponent(img) + "&gameid=" + params.gameid + "&turn=" + params.turn;
  
  sendRequest(
  	"/cgi-bin/game.rb", "POST", url,
   	function(response) {
   		 $("status").innerText = "Picture sent!";
   	});
};

