inkml_list = new Array();
mathml_list = new Array();
attribute_table_list = new Array();
filename_list = new Array();
traceid_to_node_list = new Array();
svg_list = new Array();

current_index = 0;
total_inkmls = 0;
loaded_inkmls = 0;

// histograms
writer_histogram = {};
writer_histogram.writer_list = new Array();

expression_histogram = {};
expression_histogram.expression_list = new Array();
/** determine if a string contains only whitespace **/
is_white_space = function(in_string)
{
	for(var k = 0; k < in_string.length; k++)
	{
		var c = in_string.charAt(k);
		if(c == ' ' || c == '\n' || c == '\t' || c == '\r')
			continue;
		else
			return false;
	}
	return true;
}

// dictionaroy to convert latex weirdness to unicode

mathml_dictionary = new Array();

mathml_dictionary['\\alpha'] = '\u03B1';
mathml_dictionary['\\beta'] = '\u03B2';
mathml_dictionary['\\gamma'] = '\u03B3';
mathml_dictionary['\\phi'] = '\u03C6';
mathml_dictionary['\\pi'] = '\u03C0';
mathml_dictionary['\\theta'] = '\u03B8';
mathml_dictionary['\\infty'] = '\u221E';
mathml_dictionary['\\pm'] = '\u00b1';
mathml_dictionary['\\div'] = '\u00f7';
mathml_dictionary['\\times'] = '\u00d7';
mathml_dictionary['\\sum'] = '\u03A3';
mathml_dictionary['\\log'] = "log";
mathml_dictionary['\\sin'] = "sin";
mathml_dictionary['\\cos'] = "cos";
mathml_dictionary['\\tan'] = "tan";
mathml_dictionary['\\ldots'] = '\u2026';
mathml_dictionary['\\neq'] = '\u2260';
mathml_dictionary['\\lt'] = '\u003C';
mathml_dictionary['\\gt'] = '\u003E';
mathml_dictionary['\\geq'] = '\u2265';
mathml_dictionary['\\leq'] = '\u2264';
mathml_dictionary['\\rightarrow'] = '\u2192';
mathml_dictionary['\\lim'] = "lim";
mathml_dictionary['\\int'] = '\u222b';
mathml_dictionary['\\sqrt'] = '\u221A';

mathml_dictionary['alpha'] = '\u03B1';
mathml_dictionary['beta'] = '\u03B2';
mathml_dictionary['gamma'] = '\u03B3';
mathml_dictionary['phi'] = '\u03C6';
mathml_dictionary['pi'] = '\u03C0';
mathml_dictionary['theta'] = '\u03B8';
mathml_dictionary['infty'] = '\u221E';
mathml_dictionary['pm'] = '\u00b1';
mathml_dictionary['div'] = '\u00f7';
mathml_dictionary['times'] = '\u00d7';
mathml_dictionary['sum'] = '\u03A3';
mathml_dictionary['log'] = "log";
mathml_dictionary['sin'] = "sin";
mathml_dictionary['cos'] = "cos";
mathml_dictionary['tan'] = "tan";
mathml_dictionary['ldots'] = '\u2026';
mathml_dictionary['neq'] = '\u2260';
mathml_dictionary['lt'] = '\u003C';
mathml_dictionary['gt'] = '\u003E';
mathml_dictionary['geq'] = '\u2265';
mathml_dictionary['leq'] = '\u2264';
mathml_dictionary['rightarrow'] = '\u2192';
mathml_dictionary['lim'] = "lim";
mathml_dictionary['int'] = '\u222b';
mathml_dictionary['sqrt'] = '\u221A';



// Additions for CROHME 2013
mathml_dictionary['\\lambda'] = '\u03BB';
mathml_dictionary['\\omega'] = '\u03C9';
mathml_dictionary['\\theta'] = '\u03B8';
mathml_dictionary['\\sigma'] = '\u03C3';
mathml_dictionary['\\mu'] = '\u03BC';
mathml_dictionary['\\Delta'] = '\u0394';

mathml_dictionary['\\ast'] = '\u002A';
mathml_dictionary['\\wedge'] = '\u2227';
mathml_dictionary['\\vee'] = '\u2228';
mathml_dictionary['\\supset'] = '\u2283';
mathml_dictionary['\\subset'] = '\u2282';
mathml_dictionary['\\forall'] = '\u2200';

mathml_dictionary['\\exists'] = '\u2203';
mathml_dictionary['\\partial'] = '\u2202';
mathml_dictionary['\\cup'] = '\u222A';
mathml_dictionary['\\cap'] = '\u2229';
mathml_dictionary['\\in'] = '\u2208';
mathml_dictionary['\\cdots'] = '\u22EF';
mathml_dictionary['\\prime'] = '\u2032';


mathml_dictionary['lambda'] = '\u03BB';
mathml_dictionary['omega'] = '\u03C9';
mathml_dictionary['theta'] = '\u03B8';
mathml_dictionary['sigma'] = '\u03C3';
mathml_dictionary['mu'] = '\u03BC';
mathml_dictionary['Delta'] = '\u0394';

mathml_dictionary['ast'] = '\u002A';
mathml_dictionary['wedge'] = '\u2227';
mathml_dictionary['vee'] = '\u2228';
mathml_dictionary['supset'] = '\u2283';
mathml_dictionary['subset'] = '\u2282';
mathml_dictionary['forall'] = '\u2200';

mathml_dictionary['exists'] = '\u2203';
mathml_dictionary['partial'] = '\u2202';
mathml_dictionary['cup'] = '\u222A';
mathml_dictionary['cap'] = '\u2229';
mathml_dictionary['in'] = '\u2208';
mathml_dictionary['cdots'] = '\u22EF';
mathml_dictionary['prime'] = '\u2032';



/** 
	Performs a Deep Copy of the mathml, and rebuilds each element in the proper namespace 
	for use in an xhtml file for display
**/
convert_math_nodes = function(in_node)
{
	// expects in_node to be an element
	var result = document.createElementNS('http://www.w3.org/1998/Math/MathML', in_node.nodeName);
	// copy attributes
	var attributes = in_node.attributes;
	for(var k = 0; k < attributes.length; k++)
	{
		var pair = attributes.item(k);
		result.setAttribute(pair.nodeName, pair.nodeValue);
	}
	
	var child_list = in_node.childNodes;
	for(var k = 0; k < child_list.length; k++)
	{
		var child = child_list.item(k);
		switch(child.nodeType)
		{
			case 1: //ELEMENT_NODE:
				result.appendChild(convert_math_nodes(child));
				break;
			case 3: //TEXT_NODE
				if(is_white_space(child.data) == false)
				{
					var data = mathml_dictionary[child.data];
					var text;
					if(typeof data == "undefined")
						text = document.createTextNode(child.data)
					else
						text = document.createTextNode(data);
					result.appendChild(text);				
				}
				break;
		}
	}
	
	return result;
}

build_trace_to_mathml_node_map = function(in_mathml, in_tracegroups)
{
	// build map of xml:id attributes to mathml nodes
	var xmlid_to_mathnode = {};
	
	var node_stack = new Array();
	node_stack.push(in_mathml);
	
	while(node_stack.length > 0)
	{
		var math_node = node_stack.pop();
		var attributes = math_node.attributes;
		for(var k = 0; k < attributes.length; k++)
		{
			var pair = attributes.item(k);
			//pair.nodeName, pair.nodeValue
			if(pair.nodeName == "xml:id")
			{
				xmlid_to_mathnode[pair.nodeValue] = math_node;
				break;
			}
		}
	
		var child_list = math_node.childNodes;
		for(var k = 0; k < child_list.length; k++)
		{
			var child = child_list.item(k);
			if(child.nodeType == 1)	// ELEMENT_NODE
			{
				node_stack.push(child);
			}
		}
	}
	
	// now build map from trace id to mathml node
	
	var trace_id_to_mathmlnode = {};
	for(var k = 0; k < in_tracegroups.length; k++)
	{
		var tracegroup = in_tracegroups.item(k);
		if(tracegroup.parentNode.nodeName == "traceGroup")
		{
			var traceViews = tracegroup.getElementsByTagName("traceView");
			var annotationxml = tracegroup.getElementsByTagName("annotationXML").item(0);
			var href = annotationxml.getAttribute("href");
			for(var j = 0; j < traceViews.length; j++)
			{
				var trace_data_ref = traceViews.item(j).getAttribute("traceDataRef");
				trace_id_to_mathmlnode[trace_data_ref] = xmlid_to_mathnode[href];
				console.log(trace_data_ref + " " + href);
			}
		}
	}
	
	return trace_id_to_mathmlnode;
}


// timeout variable to handle animations
animation_timeout = null;
/** Convert a list of trace nodes to an SVG file **/
trace_nodes_to_svg = function(trace_nodes, global_index, numChannels)
{
	// build our root svg
	result_svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
		result_svg.setAttribute("xmlns", "http://www.w3.org/2000/svg");

	// rectangle to listen for clicks
	rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
		rect.setAttribute("id", "rectangle");
		rect.setAttribute("width", "100%");
		rect.setAttribute("height", "100%");
		rect.setAttribute("fill", "white");
		
		rect.addEventListener("click",
		function()
		{
			// cancel previous animation
			clearTimeout(animation_timeout);
			// setup animations
			var paths = this.parentNode.getElementsByTagName("path");
			var first_trace_total_length;
			// 'clear' the pen strokes
			for(var k = 0; k < paths.length; k+=2)
			{
				var p = paths.item(k);
				p.setAttribute("stroke-width", 1);
				p.setAttribute("stroke-dashoffset", p.total_length);
				
				if(k == 0)
				{
					animating_trace = p;
					first_trace_total_length = p.total_length;
				}
			}
			
			// recursive animation call
			/**
				total_traces - Total number of traces in this svg
				trace_id - The id of the currently drawn trace
				utc_ms - Previous time in milliseconds
				trace_speed - The speed to move the 'pen'
				previous_offset - The previous position in the dash pattern of the pen
			**/
			animate_traces = function(total_traces, trace_id, utc_ms, trace_speed, previous_offset)
			{
				var current_time = (new Date()).getTime();
				var delta_t = (current_time - utc_ms) / 1000.0;	// delta t in seconds
				
				var new_offset = previous_offset - delta_t * trace_speed;
				
				if(new_offset <= 0.0)
				{
					animating_trace.setAttribute("stroke-dashoffset", 0);
					trace_id++;
					// end condition
					if(trace_id == total_traces / 2)
					{
						var paths = animating_trace.parentNode.parentNode.getElementsByTagName("path");
						for(var k = 0; k < paths.length;k+=2)
						{
							paths.item(k).setAttribute("stroke-width", 4);
						}
						return;
					}
					// set us up with next trace
					else
					{
						var trace_list = animating_trace.parentNode.parentNode.getElementsByTagName("path");
						animating_trace = trace_list.item(2 * trace_id);
						new_offset = animating_trace.total_length + new_offset;
						animating_trace.setAttribute("stroke-dashoffset", new_offset);
					}
				}
				else
				{
					animating_trace.setAttribute("stroke-dashoffset", new_offset);
				}
				
				
				var sb = new StringBuilder();
				sb.append("animate_traces(").append(total_traces).append(',').append(trace_id).append(',').append(current_time).append(',').append(trace_speed).append(',').append(new_offset).append(");");
				animation_timeout = setTimeout(sb.toString());				
			}
			
			// first call
			animate_traces(paths.length, 0, (new Date()).getTime(), this.trace_speed, first_trace_total_length);
		},
		false
		);	
		
	result_svg.appendChild(rect);
		
	// create group for the traces
	trace_group = document.createElementNS('http://www.w3.org/2000/svg', 'g');
		trace_group.setAttribute("id", "traces");
	result_svg.appendChild(trace_group);
	
	// now parse the trace data
	var traces = new Array();
	// length of each trace
	var trace_lengths = new Array();
	// trace id (from xml) for each trace
	var trace_ids = new Array();
	
	// colors for traces
	var trace_colors = new Array();
	
	var classification = new Array();
	
	// extents of this stroke
	var min_x = Number.POSITIVE_INFINITY;
	var min_y = Number.POSITIVE_INFINITY;
	var max_x = Number.NEGATIVE_INFINITY;
	var max_y = Number.NEGATIVE_INFINITY;
	
	// smallest distance between points
	var min_distance = Number.POSITIVE_INFINITY;
	
	var mean_distance = 0.0;
	var total_points = 0;
	
	// parsing the inkml trace nodes
	for(var k = 0; k < trace_nodes.length; k++)
	{
		trace_ids.push(trace_nodes.item(k).getAttribute("id"));
		trace_colors.push( trace_nodes.item( k ).getAttribute( "color" ) );
		classification.push( trace_nodes.item( k ).getAttribute( "classification" ) );
		
		// parse points using regular expressions
		var raw_point_text = trace_nodes.item(k).textContent; 
		// remove any newlines
		var pattern = /\n+/g;
		pattern.compile(pattern);
		var point_text = raw_point_text.replace(pattern, "");

		// split on comma, white space
		pattern = /,*\s+/g;
		pattern.compile(pattern);
		var point_strings = point_text.split(pattern);
	
		//  build the path
		var sb = new StringBuilder();	
		
		var point_list = new Array();
		var trace_length = 0.0;
		for(var j = 0; j < point_strings.length; j+=numChannels)
		{
			var x = parseFloat(point_strings[j]);
			var y = parseFloat(point_strings[j+1]);
		
			if(j != 0)
			{
				// data from ICDAR has redundant first nodes, so check for duplicate sequential nodes here
				if(point_list[j-2] == x && point_list[j-1] == y)
					continue;
					
				var delta_x = x - point_list[point_list.length - 2];
				var delta_y = y - point_list[point_list.length - 1];
				
				// update sample metrics
				var distance = Math.sqrt(delta_x * delta_x + delta_y * delta_y);
				mean_distance += distance;
				trace_length += distance;
				total_points++;
			}
		
			point_list.push(x);
			point_list.push(y);
		
			// update extents
		
			min_x = Math.min(min_x, x);
			min_y = Math.min(min_y, y);
			max_x = Math.max(max_x, x);
			max_y = Math.max(max_y, y);
		}
		
		traces.push(point_list);
		trace_lengths.push(trace_length);
	}
	
	// get size of the math expression
	var size_x = max_x - min_x;
	var size_y = max_y - min_y;
	
	// calculate average trace length (in icdar distance)
	var mean_trace_length = mean_distance / traces.length;
	
	// calculate scale factor to use
	mean_distance /= total_points;
	var scale = 2.0 / mean_distance;
	
	// translation of points
	var trans_x = -min_x; 
	var trans_y = -min_y;
	
	// upate svg size to fit the data
	result_svg.setAttribute("width", size_x * scale + 20);
	result_svg.setAttribute("height", size_y * scale + 20);

	rect.trace_speed = mean_trace_length * scale / 0.5;	// speed to draw a trace (ie, how fast the pen moves)
	
	// build svg elements
	for(var k = 0; k < traces.length; k++)
	{
		// contains list of circles and the polyline
		var stroke_group = document.createElementNS('http://www.w3.org/2000/svg', 'g');
	
		// contains the list of circles
		var circle_group = document.createElementNS('http://www.w3.org/2000/svg', 'g');
		// string builder used to build the point list
		var sb = new StringBuilder();
		
		for(var j = 0; j < traces[k].length; j+=2)
		{
			var x = traces[k][j];
			var y = traces[k][j+1]
		
			// map to new svg space
			x = (x + trans_x) * scale + 10;
			y = (y + trans_y) * scale + 10;
		
			// build path data
			traces[k][j] = x;
			traces[k][j+1] = y;
			if(j == 0)
				sb.append('M');
			else if(j == 2)
				sb.append(' L');
			else
				sb.append(' ');
				
			sb.append(x).append(' ').append(y);
			
			// draw individual sample points
			var circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
			
			if(j == 0)
			{
				circle.setAttribute("class", "first_point");
				circle.setAttribute("r", 4);
			}
			else if(j == (traces[k].length - 2))
			{
				circle.setAttribute("class", "end_point");
				circle.setAttribute("r", 4);
			}
			else
			{
				circle.setAttribute("class", "mid_point");
				circle.setAttribute("r", 3);
			}

			circle.setAttribute("cx", x);
			circle.setAttribute("cy", y);
			
		
			circle_group.appendChild(circle);
			
		}
		
		//  build the path
		var path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
		
		path.setAttribute( "stroke", trace_colors[ k ] == null ? "#000000" : trace_colors[ k ] );
		
		path.setAttribute("d", sb.toString());
		path.total_length = path.getTotalLength();
		path.trace_id = k;
		
		path.setAttribute("class", "trace");
		path.setAttribute("stroke-dashoffset", 0);
		path.setAttribute("stroke-dasharray", path.total_length + " " + path.total_length);
		path.setAttribute("stroke-width", 4);
		
		path.setAttribute("id", "path_" + k);
		
		// build events to show/hide circles
		circle_group.style.visibility = "hidden";
		
		var mouse_path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
		mouse_path.setAttribute("fill", "none");
		mouse_path.setAttribute("class", "invisible");
		mouse_path.setAttribute("d", sb.toString());
		
		mouse_path.inkml_index = global_index;
		mouse_path.trace_id = trace_ids[k];
		
		mouse_path.classification_table = classificationToTable( classification[ k ] );
		
		path.inkml_index = global_index;
		path.trace_id = trace_ids[k];
		
		mouse_path.addEventListener("mouseover",
		function()
		{
			this.parentNode.getElementsByTagName("g").item(0).style.visibility = "visible";
			var node = traceid_to_node_list[this.inkml_index][this.trace_id];
			node.setAttribute("style", "outline:#000 dotted thin;background:orange;");
			
			var table = document.getElementById( "classification_div" );
			table.appendChild( this.classification_table );
			
			/*
			var table = attribute_table_list[current_index];
			while(table.math_jax.hasChildNodes())
				table.math_jax.removeChild(table.math_jax.lastChild);
			table.math_jax.appendChild(mathml_list[current_index]);
			MathJax.Hub.Queue(["Typeset",MathJax.Hub,table.math_jax]);			
			*/
		},
		false
		);
		
		mouse_path.addEventListener("mouseout",
		function()
		{
			this.parentNode.getElementsByTagName("g").item(0).style.visibility = "hidden";
			var node = traceid_to_node_list[this.inkml_index][this.trace_id];
			node.setAttribute("style", "");
			
			var table = document.getElementById( "classification_div" );
			table.removeChild( table.firstChild );
			/*
			var table = attribute_table_list[current_index];
			while(table.math_jax.hasChildNodes())
				table.math_jax.removeChild(table.math_jax.lastChild);
			table.math_jax.appendChild(mathml_list[current_index]);
			MathJax.Hub.Queue(["Typeset",MathJax.Hub,table.math_jax]);		
			*/
		},
		false
		);
		
		// add circles and path to stroke group
		stroke_group.appendChild(path);
		stroke_group.appendChild(circle_group);
		stroke_group.appendChild(mouse_path);
		
		
		// add the stroke data to the trace group
		trace_group.appendChild(stroke_group);
	}
	
	return result_svg;
}

/** Pull out attributes and build the file attribute table shown
 *  to the user. **/
build_attribute_table = function(annotation_nodes, filename, mathml)
{
	var result_table = document.createElement("table");
		result_table.setAttribute("id", "attribute_table");
	
	// second row
	var second_row = document.createElement("tr");
		var td_attr_name = document.createElement("td");
			td_attr_name.setAttribute("class", "attribute_name");
			td_attr_name.innerHTML = "<b>File:</b>";
		var td_attr_value = document.createElement("td");
			td_attr_value.setAttribute("class", "attribute_value");
			td_attr_value.innerHTML = filename;
		var td_mathml = document.createElement("td");
			td_mathml.setAttribute("rowspan", annotation_nodes.length);
			var div_math_div = document.createElement("div");
				div_math_div.setAttribute("id", "math_div");
				div_math_div.appendChild(mathml);
			td_mathml.appendChild(div_math_div);
			//result_table.math_jax = div_math_div;	
		
		second_row.appendChild(td_attr_name);
		second_row.appendChild(td_attr_value);
		second_row.appendChild(td_mathml);
		
		// R.Z. 2013: Removing for space.
		/* var td_classification = document.createElement("td");
			td_classification.setAttribute("rowspan", annotation_nodes.length);
			var div_classification_div = document.createElement("div");
				div_classification_div.setAttribute("id", "classification_div");
			td_classification.appendChild(div_classification_div);
		second_row.appendChild(td_classification);
		*/
	result_table.appendChild(second_row);
	
	var writer, age, gender, hand;
	var expression;
	
	
	for(var k = 0; k < annotation_nodes.length; k++)
	{
		var annotation = annotation_nodes.item(k);
		
		if(annotation.parentNode.nodeName == "traceGroup")
			continue;
		
		var type = annotation.getAttribute("type");
		var value = annotation.textContent;

		switch(type)
		{
			case "writer":
				writer = value;
				break;
			case "age":
				age = value;
				break;
			case "gender":
				gender = value;
				break;
			case "hand":
				hand = value;
				break;
			case "truth":
				expression = value;
				break;
		}
		
		console.log("Read attribute: (" + type + ", " + value + ")");
		if (type != "truth") {
		var row_n = document.createElement("tr");
			var td_attr = document.createElement("td");
				td_attr.setAttribute("class", "attribute_name");
				td_attr.innerHTML = type + ":";
			row_n.appendChild(td_attr);
			var td_value = document.createElement("td");
				td_value.setAttribute("class", "attribute_value");
				td_value.innerHTML = value;
			row_n.appendChild(td_value);
		    result_table.appendChild(row_n);
		}
	}
	
	var writer_name = writer;// + "|" + age + "|" + gender + "|" + hand;
	
	var count = writer_histogram[writer_name];
	if(typeof count == "undefined")
	{
		writer_histogram[writer_name] = 1;
		writer_histogram.writer_list.push(writer_name);
	}
	else
		writer_histogram[writer_name]++;

	count = expression_histogram[expression];
	if(typeof count == "undefined")
	{
		expression_histogram[expression] = 1;
		expression_histogram.expression_list.push(expression);
	}
	else
		expression_histogram[expression]++;
		
	return result_table;
}

on_xml_load = function(event)
{
    // HACK: allow a list of strings rather than an event to be passed in.
	// length field is undefined for event object, but not list 
	// of strings.
	inkml_list = new Array(); // EMPTY OUT THE FILE LIST.

	var file_list = new Array();
	if (event.length == undefined )
	{
		// NOTE: an array of file *objects*
		file_list = event.target.files;
	} else {
		// NOTE: a list of strings (URLs for .inkml files)
		file_list = event;
	}

	total_inkmls = file_list.length;
	for(var k = 0; k < file_list.length; k++)
	{
		var file = file_list[k];
		if (event.length == undefined)
			filename_list[k] = file.name;
		else
			filename_list[k] = file;
		//console.log("FN:" + file);
	
		parseInkML = function(inkmlText,currentIndex) 
		{
			var parser = new DOMParser();
			var xmlDOC = parser.parseFromString(inkmlText, "text/xml");
			
			// DEBUG (RZ): Get the number of channels, use when parsing
			// stroke data to handle files with time information.
			numChannels = xmlDOC.getElementsByTagName("channel").length;
			console.log("Channels: " + numChannels);

			// get our math node
			var math_nodes = xmlDOC.getElementsByTagName("math");

			if(math_nodes.length == 0)
			{
				alert(filename_list[k] + " does not contain MathML.");
				return;
			}
			mathml = convert_math_nodes(math_nodes.item(0));
			mathml_list[currentIndex] = mathml;

			// build annotations
			annotation_nodes = xmlDOC.getElementsByTagName("annotation");
			if(annotation_nodes.length == 0)
			{
				alert(filename_list[currentIndex] + " does not contain any annotation nodes.");
				return;				
			}
			var table = build_attribute_table(annotation_nodes, filename_list[currentIndex], mathml);
				//filename_list[currentIndex], mathml);
			attribute_table_list[currentIndex] = table;
			
			//  build our mapping from trace ids to xml:ids in mathml
			trace_group_nodes = xmlDOC.getElementsByTagName("traceGroup");
			traceid_to_node_list[currentIndex] = build_trace_to_mathml_node_map(mathml, trace_group_nodes);
			
			// get our trace nodes			
			trace_nodes = xmlDOC.getElementsByTagName("trace");
			var svg = null;
			if(trace_nodes.length > 0)
				svg = trace_nodes_to_svg(trace_nodes, currentIndex, numChannels);
			
			svg_list[currentIndex] = svg;			
			
			if(currentIndex == 0)
			{
				current_index = 0;
				update_view();
			}
			
			loaded_inkmls++;
		}

		// Read in local files if file input interface used; otherwise load data
		// from URL.
		if(event.length == undefined)
		{
			var r = new FileReader();
			r.onload = function(e)
			{
				inkml_list.push(e.target.result);
				parseInkML(e.target.result,e.currentTarget.index);
			}
			r.index = k;
			r.readAsText(file);
		} else {
			// Read URLs as URLs
			//console.log("OUTER SCOPE ALIVE.");
			var inkmlText = "";
			$.ajax({
				url: file,
				data: inkmlText,
				success: function( data ) {
					console.log(data);
					console.log("ALIVE");
					parseInkML(data,k);
				},
				error: function (err) {
					console.log("ERROR...");
					console.log(inkmlText);
					console.log(err.toString());
				}
			});
			//$.get(file,urlFileCallback);
		}
	}
}

// updates the screen to reflect the current inkml file
update_view = function()
{
	console.log(current_index);
	
	// insert the svg
	var svg = svg_list[current_index];
	var ink_div = document.getElementById("ink_div");
	while(ink_div.hasChildNodes())
		ink_div.removeChild(ink_div.lastChild);
	if(svg != null)
		ink_div.appendChild(svg);


	// insert table
	var table = attribute_table_list[current_index];
	var table_div = document.getElementById("table_div");
	while(table_div.hasChildNodes())
		table_div.removeChild(table_div.lastChild);
	table_div.appendChild(table);
	
	/*
	while(table.math_jax.hasChildNodes())
		table.math_jax.removeChild(table.math_jax.lastChild);
	table.math_jax.appendChild(mathml_list[current_index]);
	//MathJax.Hub.Queue(["Typeset",MathJax.Hub,table.math_jax]);
	*/

	
	// cancel animation and reset strokes
	clearTimeout(animation_timeout);
	if(svg != null)
	{
		var paths = svg.getElementsByTagName("path");
		for(var k = 0; k < paths.length; k+=2)
		{
			var p = paths.item(k);
			p.setAttribute("stroke-width", 4);
			p.setAttribute("stroke-dashoffset", 0);
		}
	}
	document.getElementById("current_index").innerHTML = (current_index + 1) + " of " + total_inkmls;
	
	
}

// move through the list
next = function()
{
	current_index = (current_index + 1 + inkml_list.length) % inkml_list.length;
	update_view();
}

previous = function()
{
	current_index = (current_index - 1 + inkml_list.length) % inkml_list.length;
	update_view();
}

// classification attribute to printable string
classificationToString = function( data ) {
	if ( data == null ) return null;
	
	var html = "";
	var cls = data.split( "|" );
	for ( var i = 0; i < Math.min( 5, cls.length ); i++ ) {
		var c = cls[ i ].split( "," );
		html += "<span class=\"classification_div_element\"><span class=\"classification_div_index\">" + i + "</span>"
			+ "<span class=\"classification_div_symbol\">" + c[ 0 ] + "</span>"
			+ "<span class=\"classification_div_prob\">" + c[ 1 ] + "</span></span>";
	}
	return html;
}

classificationToTable = function( data ) {	
	var table = document.createElement( "div" );
	table.setAttribute( "class", "classification_div_table" );	
	if ( data == null ) return table;
	var cls = data.split( "|" );
	
	html = "";
	for ( var i = 0; i < Math.min( 10, cls.length ); i++ ) {		
		var c = cls[ i ].split( "," );
		html += "<div><span class=\"classification_div_symbol\">" + c[ 0 ] + "</span>"
			+ "<span class=\"classification_div_prob\">" + c[ 1 ] + "</span></div>";
	}
	
	console.log( html );
	table.innerHTML = html;
	return table;
}

if(window.FileReader)
{
	document.getElementById("inkml_input").addEventListener("change", on_xml_load, true);
}
else
{
	alert("This webpage requires a modern browser which supports the FileReader JavaScript Object");
}

// listen for left/right keystrokes
navigation = function(event)
{
	if(event.which == 39)	// right arrow
	{
		event.preventDefault();
		next();
	}
	else if(event.which == 37)	// left arrow
	{
		event.preventDefault();
		previous();
	}
}

// set upu events
document.getElementById("prev_button").addEventListener("click", previous, true);
document.getElementById("next_button").addEventListener("click", next, true);
document.addEventListener("keydown", navigation, true);

// Parse the query string (i.e. arguments passed in fields attached to the URL)
// Credit: modified from StackOverflow snippet by Moin Zaman.
function getField( fieldName, urlString )
{
	var regexPattern = "[\\?&]" + fieldName + "=([^&#]*)";
	var regex = new RegExp( regexPattern );
	var match = regex.exec( urlString );
	if ( match == null )
		return "";
	else
		// Replace '+' by a space.
		return decodeURIComponent(match[1].replace(/\+/g, " "));
}

// Extract the path containing the inkml files; and then extract fields 
// of interest.
// May need to provide the absolute path.
var urlString = window.location.href;
var urlPrefixString = getField( "path", urlString);
var fileList = getField( "files", urlString).split(",");
if (fileList[0] == "") 
{
	fileList = [];
}


console.log(fileList.length + " files passed in URL Query String");

// Construct list of (absolute) files, invoke on_xml_load handler.
for (i=0; i < fileList.length; i++)
{
	fileList[i] = urlPrefixString + fileList[i];
}

if(fileList.length > 0) 
{
	console.log("FILES FROM COMMAND LINE: \n" + fileList);
	on_xml_load(fileList);
}
