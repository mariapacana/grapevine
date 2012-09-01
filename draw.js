//This borrows liberally from various Canvas tutorial sites 
//including http://dev.opera.com/articles/view/html5-canvas-painting/
//and others I can't remember!
var can;
var ctx;
var canX;
var canY;
var canStyle = "#000000";
var canWidth = 2;
var canDraw = false;
var erasing = false;
var eraseButton;
var started = false;

function onload() {
	
};

function draw(e) {
	can = $("myCanvas"); 
	form = $("form");
	picture = document.getElementsByClassName("picture");
	status = $("status");
	eraseButton = $("eraseButton");
	ctx = can.getContext("2d");
	
	setUpCanvas(can);
	
	can.addEventListener("mousedown", mousedown, false);
	can.addEventListener("mouseup", mouseup, false);
	
	//Tries to prevent I-beam
	if (!e) var e = window.event;
	e.preventDefault();	
};

function setUpCanvas (can) {		
	//console.log(erasing);
	//console.log(can.style.cursor);
	if (!erasing) {
		can.style.cursor = "crosshair";
	} else {
		can.style.cursor = "url('/images/eraser.png'), auto";
	}
};

function mousedown(e) {
	//Tries to prevent I-beam
	if (!e) var e = window.event;
	e.preventDefault();	
		
	canDraw = true;
	can.addEventListener("mousemove", mousemove, false);
  
	canX = e.pageX - can.offsetLeft;
  canY = e.pageY - can.offsetTop;
	ctx.fillRect(canX,canY,1,1);

};

function mouseup(e) {
	canDraw = false;
};

function mousemove(e) {
	if (!e) var e = event;
		canX = e.pageX - can.offsetLeft;
    canY = e.pageY - can.offsetTop;
    ctx.strokeStyle = canStyle;
    ctx.lineWidth = canWidth;
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

function eraseall() {
	ctx.clearRect(0,0,can.width,can.height);
	console.log('mew');
};

function toggleErase() {
	erasing = !erasing;	
	if (canStyle == "#000000") {
		canStyle = "#FFFFFF";
		canWidth = 20;
		eraseButton.innerText = "Draw";
	} else {
		canStyle = "#000000";
		canWidth = 2;
		eraseButton.innerText = "Erase";
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
  
  if (email.match(/,/)) {
   	email = email.split(/,/);
  } else {
  	email = email.split(/ /);
  }
	
	for (var i = 0; i < email.length; i++) {
		if (!email[i].match(/.*@.*\..*/) || email[i].length == 0) {
		$("status").innerText = "Please enter valid email addresses.";
    return;
    }
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

