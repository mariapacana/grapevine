function $(id) {
  return document.getElementById(id);
}

// Sends an XHR.  |data| will be passed in the request body, and the response from the server will be passed to callback
// if non-NULL.
function sendRequest(url, method, data, callback) {
  var xhr = window.XMLHttpRequest ? new XMLHttpRequest() : new ActiveXObject("Microsoft.XMLHTTP");
  xhr.onreadystatechange = function() {
  if (xhr.readyState == 4) {
    console.log("status=" + xhr.status + " text=" + xhr.responseText);
  if (xhr.status == 200) {
  if (callback)
    callback(xhr.responseText);
  } else {
    alert("Got error " + xhr.status + " from server: " + xhr.responseText);
  }
  }
};
xhr.open(method, url, true); 
  if (method == 'POST')
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.send(data);  
}

//Hides the "how to" div that pops up when the page is opened.
function hide() {
  $("howto").style.display = "none";
}
