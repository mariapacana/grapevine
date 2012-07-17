//This borrows liberally from various Canvas tutorial sites 
//including http://dev.opera.com/articles/view/html5-canvas-painting/
//and others I can't remember!

function $(id) {
	return document.getElementById(id);
}

function sendRequest(url, method, data, callback) {
  var xhr = window.XMLHttpRequest ? new XMLHttpRequest() : new ActiveXObject("Microsoft.XMLHTTP");
	xhr.onreadystatechange = function() {
  	if (xhr.readyState == 4) {
  	  console.log("status=" + xhr.status + " text=" + xhr.responseText);
  	  if (xhr.status == 200) {
      	callback(xhr.responseText);
      } else {
				alert("Got error " + xhr.status + " from server: " + xhr.responseText);
      }
    }
  };
	xhr.open(method, url, true); //must have a web server running! XHR no work w/o http
	if (method == 'POST')
	  xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
	xhr.send(data);  
}

function load(){
	draw();
}

/*
function addsentence(turn) {
  var newsection = document.createElement('section');
  var sectionIdName = turn;
  var sectionIdName = "sentence";
  newsection.setAttribute('id',sectionIdName);
  newdiv.setAttribute('class',sectionClass);
}*/
