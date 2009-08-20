var gl_url_www = 'http://localhost:8080';
var timeout_time = 15;
var timeoutId;
var prev_req_aborted = 0;

function callInProgress( req ) {
	switch ( req.readyState ) {
		case 1, 2, 3:
			return true;
			break;

		// case 4 and 0
		default:
			return false;
			break;
	}
}


function gen_request(handler,method,url,content) {
    var req = null;
    if ( window.XMLHttpRequest ) {
        req = new XMLHttpRequest();
    } else if (window.ActiveXObject) {
        req = new ActiveXObject("Microsoft.XMLHTTP");
    }
    if (req == null) return false;

    req.onreadystatechange = function() {
        handler(req);
    }
	timeoutId = window.setTimeout(
		function() {
			if ( !callInProgress(req) ) {
				req.abort();
				prev_req_aborted = 1;
				dictionary_request();
			}
			
		},
		timeout_time * 1000
	);

    req.open("GET",url,true);
    req.send(content);
    return true;
}



function handle_dictionary(req) {
    if ( req.readyState==4 && req.status==200 ) {
        var response_data;
        if ( req.responseText == '' ) return false;
        try {
            eval( 'response_data='+req.responseText+';' );
        } catch(e){
            return false;
        }
        if ( response_data['data']['html'] ) {
        	document.getElementById('dictionary_div').innerHTML = response_data['data']['html'];
		}

		window.clearTimeout(timeoutId);
	    dictionary_request();

        return true;
    }
    return false;
}


function dictionary_request() {
    url = gl_url_www+'/dictionary';
    if ( prev_req_aborted ) {
		url += '?prev_req_aborted=1';
		prev_req_aborted = 0;
	}
    if ( !gen_request(handle_dictionary, 'GET', url, null )) {
		dictionary_settimeout(1);
		prev_req_aborted = 1;
        return false;
    }
    return true;
}


function dictionary_settimeout(secs) {
    window.setTimeout("dictionary_request("+secs+")", secs*1000);
}


function dictionary_start(secs) {
    document.getElementById('dictionary_div').innerHTML = "no data ...";
    dictionary_request();
}
