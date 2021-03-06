// Copyright 2013 Maria Pacana.
// This borrows liberally from various Canvas tutorial sites, such as 
// http://dev.opera.com/articles/view/html5-canvas-painting/.

var erasing = false;
var isDrawing = false;

var state = {
  penWidth: 2,
  penColor: "#000000"
};

// Initializes global state object with important elements.
function initState(hasPicture, hasSentence) {
  state.close = $("close");
  state.status = $("status");
  state.submitButton = $("submitButton");

  if (hasPicture) {
    state.canvas = $("myCanvas"); 
	  state.context = state.canvas.getContext("2d");
    state.eraseAllButton = $("eraseAllButton");
    state.eraseButton = $("eraseButton");
    state.picture = $("picture");
  }
  
	if (hasSentence) {
		state.sentence = $("sentenceInput").value;
		state.submitSentenceButton = $("submitSentenceButton");
	}
};

// Onload for main Grapevine page for first player.
function onload() {
  var hasPicture = true;
  var hasSentence = true;
  
  initState(hasPicture, hasSentence);
	setUpTurn();
	
	// Event listeners for submitting a first turn and for Recaptcha.
	state.submitButton.addEventListener("click", submitFirstTurn, false);
	
	Recaptcha.create("6Le9XNYSAAAAAFxZ0cHVUx3_tC4PI1Tjvzhrg8pB",
	   "recaptcha",
    {
      theme: "clean",
      // callback: Recaptcha.focus_response_field
    }
  );
};

function setUpTurn() {
  // Will close the "How To" div.
	state.close.addEventListener("click", hide, false);
	
	// Sets up event listeners for drawing.
  console.log(isDrawing);
  state.canvas.addEventListener("mousedown", mousedown, false);
	state.canvas.addEventListener("mouseup", mouseoff, false);
	state.canvas.addEventListener("mousemove", mousemove, false);
	state.canvas.addEventListener("mouseout", mouseoff, false);
	
	// Sets up event listeners for erasing.
	state.canvas.style.cursor = "crosshair";
	state.eraseAllButton.addEventListener("click", eraseAll, false);
	state.eraseButton.addEventListener("click", toggleErase, false);
};

// Onload for even-numbered players who are submitting pictures.
function onloadSentence() {
  var hasPicture = true;
  var hasSentence = false;
  initState(hasPicture, hasSentence);
  setUpTurn();

	state.submitButton.addEventListener("click", submitPic, false);
};

// Onload for even-numbered players who are submitting sentences.
function onloadPicture() {
  var hasPicture = false;
  var hasSentence = true;
  initState(hasPicture, hasSentence);
	
	state.close.addEventListener("click", hide, false);
	state.submitSentenceButton.addEventListener("click", submitSentence, false);
};

// Begins to draw a path on mousedown.
function mousedown(e) {
	if (!e) var e = window.event;
	e.preventDefault();		// Tries to prevent I-beam
		
	isDrawing = true;
  console.log(isDrawing);
	state.canvasX = e.pageX - state.canvas.offsetLeft;
  state.canvasY = e.pageY - state.canvas.offsetTop;
	state.context.beginPath();
  state.context.moveTo(state.canvasX, state.canvasY);
};

// Closes existing path when mouse is moved off the canvas.
function mouseoff(e) {
  state.context.closePath();
  isDrawing = false;
  console.log(isDrawing);
};

// Draws the path as mouse moves.
function mousemove(e) {
	if (!e) var e = event;
		state.canvasX = e.pageX - state.canvas.offsetLeft;
    state.canvasY = e.pageY - state.canvas.offsetTop;
    state.context.strokeStyle = state.penColor;
    state.context.lineWidth = state.penWidth;
  if (isDrawing) {
    state.context.lineTo(state.canvasX, state.canvasY);
    state.context.stroke();
    console.log(isDrawing);
  }
};

// Erases entire canvas.
function eraseAll() {
	state.context.clearRect(0, 0, state.canvas.width, state.canvas.height);
};

// Toggles between drawing and erasing (which is basically drawing with a white pen.)
function toggleErase() {
	erasing = !erasing;	
	if (erasing) {
		state.penColor = "#FFFFFF";
		state.penWidth = 20;
		state.canvas.style.cursor = "url('/images/eraser.png') 10 10, auto";
		eraseButton.innerText = "Draw";
	} else {
		state.penColor = "#000000";
		state.penWidth = 2;
		state.canvas.style.cursor = "crosshair";
		state.eraseButton.innerText = "Erase";
	}
};

function getUrlParams() {
	var url = window.location.search.substring(1).split("&");
	var params = {};
	
	for (var i = 0; i < url.length; i++) {
		var parts = url[i].split("="); 
		params[parts[0]] = parts[1];
	}
	
	return params;
	
};

// First player submits their turn, consisting of canvas data, sentence data, and recaptcha response.
function submitFirstTurn(e) {
  var img = state.canvas.toDataURL("image/png");
  var email = $("email").value.trim();
  var sentence = $("sentenceInput").value.trim();
  
  // Validates sentence content.
  if (!validateSentence(sentence)) {
  	return;
  } 
	
	// Separates emails by commas or by spaces. (Would be nice to allow a mix.)
	if (email.match(/,/)) {
   	email = email.split(/\s*,\s*/);
  } else {
  	email = email.split(/\s+/);
  }
  
  // Validates email input.
	for (var i = 0; i < email.length; i++) {
		if (!email[i].match(/.+@.+\..+/) || email[i].length == 0) {
	  	$("status").innerText = "Please enter valid email addresses.";
      return;
    }
	}	
	
	// Verifying the Recaptcha.
	var recaptchaChallenge = Recaptcha.get_challenge();
	var recaptchaResponse = Recaptcha.get_response();
  
  // Sending pic, sentence, email, & Recaptcha data to server.
  sendRequest("/cgi-bin/game.rb", "POST", 
  		        "cmd=create&data=" + encodeURIComponent(img) +   
  		        "&sentence=" + encodeURIComponent(sentence) + 
  		        "&email=" + encodeURIComponent($("email").value) +
  		        "&challenge=" + encodeURIComponent(recaptchaChallenge) +
  		        "&response=" + encodeURIComponent(recaptchaResponse),
   	function(response) {
   	  var parsedResponse = JSON.parse(response);
	 		$("status").innerText = parsedResponse.message;   	 	
		 	if (!parsedResponse.success) {
	 			Recaptcha.reload();
		 	} else {
		 	 	Recaptcha.destroy();
		 	}
  	});
};

// Submits a sentence to the server.
function submitSentence() {
	var params = getUrlParams();
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

// Submits a pic to the server.
function submitPic() {
  var img = state.canvas.toDataURL("image/png");
  var params = getUrlParams();
  var url = "cmd=pic&data=" + encodeURIComponent(img) + "&gameid=" + params.gameid + "&turn=" + params.turn;
  
  sendRequest(
  	"/cgi-bin/game.rb", "POST", url,
   	function(response) {
   	  var parsedResponse = JSON.parse(response);
 		  $("status").innerText = parsedResponse.message;
   	});
};

// Checks that player wrote a sentence and that the sentence is valid.
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
