// Copyright 2013 Maria Pacana.
// This borrows liberally from various Canvas tutorial sites, such as 
// http://dev.opera.com/articles/view/html5-canvas-painting/.

var canvas;
var context;
var canvasX;
var canvasY;
var canvasStyle = "#000000";
var canvasWidth = 2;
var canDraw = false;
var erasing = false;
var close;
var eraseAllButton;
var eraseButton;
var submitButton;
var isDrawing = false;

function onload() {
	canvas = $("myCanvas"); 
	eraseAllButton = $("eraseAllButton");
	eraseButton = $("eraseButton");
	submitButton = $("submitButton");
	close = $("close");
	picture = $("picture");
	status = $("status");
	context = canvas.getContext("2d");
	
	canvas.addEventListener("mouseover", draw, false);
	close.addEventListener("click", hide, false);
	eraseAllButton.addEventListener("click", eraseAll, false);
	eraseButton.addEventListener("click", toggleErase, false);
	submitButton.addEventListener("click", submitFirstTurn, false);
	
	Recaptcha.create("6Le9XNYSAAAAAFxZ0cHVUx3_tC4PI1Tjvzhrg8pB",
	   "recaptcha",
    {
      theme: "clean",
      // callback: Recaptcha.focus_response_field
    }
  );
};

function onloadSentence() {
	canvas = $("myCanvas"); 
	eraseAllButton = $("eraseAllButton");
	eraseButton = $("eraseButton");
	submitPicButton = $("submitPicButton");
	status = $("status");
	context = canvas.getContext("2d");
	close = $("close");
	
	canvas.addEventListener("mouseover", draw, false);
	close.addEventListener("click", hide, false);
	eraseAllButton.addEventListener("click", eraseAll, false);
	eraseButton.addEventListener("click", toggleErase, false);
	submitPicButton.addEventListener("click", submitPic, false);
};

function onloadPicture() {
	submitSentenceButton = $("submitSentenceButton");
	sentence = $("sentenceInput").value;
	status = $("status");
	close = $("close");
	
	close.addEventListener("click", hide, false);
	submitSentenceButton.addEventListener("click", submitSentence, false);
};

function draw(e) {
	setUpCanvas(canvas);
	canvas.addEventListener("mousedown", mousedown, false);
	canvas.addEventListener("mouseup", mouseup, false);
	
	// Tries to prevent I-beam
	e.preventDefault();	
};

function setUpCanvas(canvas) {		
	// console.log(erasing);
	// console.log(canvas.style.cursor);
	if (!erasing) {
		canvas.style.cursor = "crosshair";
	} else {
		canvas.style.cursor = "url('/images/eraser.png') 10 10, auto";
	}
};

function mousedown(e) {
	// Tries to prevent I-beam
	if (!e) var e = window.event;
	e.preventDefault();	
		
	canDraw = true;
	canvas.addEventListener("mousemove", mousemove, false);
  
	canvasX = e.pageX - canvas.offsetLeft;
  canvasY = e.pageY - canvas.offsetTop;
	context.fillRect(canvasX,canvasY,1,1);

};

function mouseup(e) {
	canDraw = false;
};

function mousemove(e) {
	if (!e) var e = event;
		canvasX = e.pageX - canvas.offsetLeft;
    canvasY = e.pageY - canvas.offsetTop;
    context.strokeStyle = canvasStyle;
    context.lineWidth = canvasWidth;
  if (canDraw && !isDrawing) {
    context.beginPath();
    context.moveTo(canvasX, canvasY);
    isDrawing = true;
	} else if (canDraw && isDrawing) {
    context.lineTo(canvasX, canvasY);
    context.stroke();
  } else {
  canDraw = false;
  isDrawing = false;
  }
};

function eraseAll() {
	context.clearRect(0, 0, canvas.width, canvas.height);
};

function toggleErase() {
	erasing = !erasing;	
	if (canvasStyle == "#000000") {
		canvasStyle = "#FFFFFF";
		canvasWidth = 20;
		eraseButton.innerText = "Draw";
	} else {
		canvasStyle = "#000000";
		canvasWidth = 2;
		eraseButton.innerText = "Erase";
	}
};

function getparams() {
	var url = window.location.search.substring(1).split("&");
	var params = {};
	
	for (var i = 0; i < url.length; i++) {
		var parts = url[i].split("="); 
		params[parts[0]] = parts[1];
	}
	
	return params;
	
};

function submitFirstTurn(e) {
  var img = canvas.toDataURL("image/png");
  var email = $("email").value.trim();
  var sentence = $("sentenceInput").value.trim();
  
  if (!validateSentence(sentence)) {
  	return;
  } 
	
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
	
	var recaptchaChallenge = Recaptcha.get_challenge();
	var recaptchaResponse = Recaptcha.get_response();
  
  sendRequest("/cgi-bin/game.rb", "POST", 
  		        "cmd=create&data=" + encodeURIComponent(img) +   //encodeURI changes spaces, &&s, etc.
  		        "&sentence=" + encodeURIComponent(sentence) + 
  		        "&email=" + encodeURIComponent($("email").value) +
  		        "&challenge=" + encodeURIComponent(recaptchaChallenge) +
  		        "&response=" + encodeURIComponent(recaptchaResponse),
   	function(response) {
   	  var parsedResponse = JSON.parse(response);
   	 	
		 	if (!parsedResponse.success) {
	 			switch (parsedResponse.message) {
	 				case "incorrect-captcha-sol": 
	 					$("status").innerText = "Invalid CAPTCHA answer, try again.";
	 					break;
	 				case "invalid-request-cookie":
	 					$("status").innerText = "The challenge parameter of the verify script was incorrect."; 
	 					break;
	 				default:
	 					$("status").innerText = "Failed to check CAPTCHA (" + parsedResponse.message + "). Sorry, please try again."; 
	 			}	
	 			Recaptcha.reload();
		 	} else {
		 	 	$("status").innerText = "Turn successfully submitted!";
		 	 	Recaptcha.destroy();
		 	}
  	});
};

function submitSentence() {
	var params = getparams();
	var url = "cmd=sentence&sentence="+encodeURIComponent($("sentenceInput").value)+"&gameid="+params.gameid+"&turn="+params.turn;
	var sentence = $("sentenceInput").value.trim();
  
	if (!validateSentence(sentence)) {
  	return;
  } 
	
  sendRequest(
  	"/cgi-bin/game.rb", "POST", url,
  	function(response) {
   	  var parsedResponse = JSON.parse(response);
 		  $("status").innerText = parsedResponse.message;
   	});
};

function submitPic() {
  var img = canvas.toDataURL("image/png");
  var params = getparams();
  var url = "cmd=pic&data=" + encodeURIComponent(img) + "&gameid=" + params.gameid + "&turn=" + params.turn;
  
  sendRequest(
  	"/cgi-bin/game.rb", "POST", url,
   	function(response) {
   	  var parsedResponse = JSON.parse(response);
 		  $("status").innerText = parsedResponse.message;
   	});
};

function validateSentence(sentence) {
	if (sentence == "") {
  	$("status").innerText = "Missing input in the sentence field.";
  	return false;
  } else if (sentence.length > 100) {
    $("status").innerText = "Please limit your description to 100 characters or less."
   return false;
  }
  return true;
};

