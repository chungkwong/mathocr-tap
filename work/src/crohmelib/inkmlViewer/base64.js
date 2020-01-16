
base64_lookup = new Array();
for(var k = 0; k < 26; k++)
{
	base64_lookup[k] = String.fromCharCode('A'.charCodeAt(0) + k);
	base64_lookup[k + 26] = String.fromCharCode('a'.charCodeAt(0) + k)
}

for(var k = 0; k < 10; k++)
	base64_lookup[k + 52] = String.fromCharCode('0'.charCodeAt(0) + k)
base64_lookup[62] = '+';
base64_lookup[63] = '/';

 
 function Base64()
 {

 }
 
 Base64.encode = function(in_data)
 {
	var ascii0, ascii1, ascii2;
	var b640, b641, b642, b643;

	
	
	var sb = new StringBuilder();
	
	write_bytes = function()
	{
		sb.append(base64_lookup[b640]);
		sb.append(base64_lookup[b641]);
		if(b642 == '=')
			sb.append('==');
		else		
			sb.append(base64_lookup[b642]);
		if(b643 == '=')
			sb.append('=');
		else
			sb.append(base64_lookup[b643]);
	}
	
	var i = 0;
	for(var i  = 0; i < in_data.length;)
	{
		ascii0 = in_data.charCodeAt(i++);
		ascii1 = in_data.charCodeAt(i++);
		ascii2 = in_data.charCodeAt(i++);
		
		b640 = ascii0 >> 2;
		b641 = (ascii0 & 0x3) << 4;
		if(isNaN(ascii1))
		{
			b642 = b643 = '=';
			write_bytes();
			break;
		}
		b641 += ascii1 >> 4;
		b642 = (ascii1 & 0xF) << 2;
		if(isNaN(ascii2))
		{
			b643 = '=';
			write_bytes();
			break;
		}
		b642 += ascii2 >> 6;
		b643 = ascii2 & 0x3F;
		write_bytes();
	}
	return sb.toString();	
 }
