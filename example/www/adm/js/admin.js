function AdjustDateTime()
{
	var now = new Date();
	document.getElementById ('SelectDay').selectedIndex = now.getDate() - 1;
	document.getElementById ('SelectMonth').selectedIndex = now.getMonth();
	document.getElementById ('SelectYear').value = now.getFullYear();
	document.getElementById ('SelectHour').selectedIndex = now.getHours();
	document.getElementById ('SelectMinute').selectedIndex = now.getMinutes();
	document.getElementById ('IsPublished').checked = true;
}
function AddKeyword (uri)
{
	document.getElementById ('Keywords').value += (document.getElementById ('Keywords').value ? ', ' : '') + uri;
}
