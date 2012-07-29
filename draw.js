var can;
var ctx;
var canX;
var canY;
var canDraw = false;
var started = false;

function draw() {
	can = $("myCanvas"); //This should be changed, depending.
	form = $("form");
	picture = document.getElementsByClassName("picture");
	status = $("status");
    
	ctx = can.getContext("2d");
	can.addEventListener("mousedown", mousedown, false);
	can.addEventListener("mouseup", mouseup, false);
}

function mousedown(e) {
	canDraw = true;
	can.addEventListener("mousemove", mousemove, false);
}

function mouseup(e) {
	canDraw = false;
}

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
}

//When a pic is submitted, it will do the following:
//- Say that it's been submitted.
//- Save the pic and userid to the database.
//- (For the next user) display a textbox to type in.
function submitpic(e) {
  
  var img = can.toDataURL("image/png");
  
  sendRequest("/cgi-bin/xhrtest.rb", "POST", "cmd=new&data=" + encodeURIComponent(img) + "&email="+$("email").value,
   	function(response) {
   		 $("status").innerText = "Game started!";
   	});
}

function submitsentence(gameid, turn) {
  sendRequest("/cgi-bin/xhrtest.rb", "POST", "cmd=sentence&sentence="+$("sentence").value+"&gameid="+gameid+"&turn="+turn,
  	function(response) {
  	  		 $("status").innerText = "Sentence sent!";
   	});
}


