<?php $main_page=basename(__FILE__); require('header_test.php') ?>

<script type="text/javascript"><!--
  var input_file_content = null;
  var output_file_content = null;
  var output_file_stats = null;
  var output_format = null;

  document.addEventListener("DOMContentLoaded", function() {
      getInfo();
      //console.log("DOM byl kompletně načten!");
  });

  function doSubmit() {
    var input_text;
    var input_tab = jQuery('#input_tabs>.tab-pane.active');
    if (input_tab.length > 0 && input_tab.attr('id') == 'input_file') {
      if (!input_file_content) { alert('Please load a file first.'); return; }
      input_text = input_file_content;
    } else {
      input_text = jQuery('#input').val();
    }

    //var input_text = jQuery('#input').val();
    //console.log("doSubmit: Input text: ", input_text);
    var input_format = jQuery('input[name=option_input]:checked').val();
    //console.log("doSubmit: Input format: ", input_format);
    output_format = jQuery('input[name=option_output]:checked').val();
    //console.log("doSubmit: Output format: ", output_format);
    // Zjistíme stav checkboxu s id "option-randomize"
    //var jeZaskrtnuto = $('#option_randomize').prop('checked');
    //console.log("doSubmit: Randomize: ", jeZaskrtnuto);
    var options = {text: input_text, input: input_format, output: output_format};
    //console.log("doSubmit: options: ", options);
    // Přidáme parametr "randomize", pokud je checkbox zaškrtnutý
    //if (jeZaskrtnuto) {
    //  options.randomize = null; // Nebo prázdný řetězec, záleží na konkrétní implementaci serveru
    //}

    var form_data = null;
    if (window.FormData) {
      form_data = new FormData();
      for (var key in options) {
        form_data.append(key, options[key]);
      }
    }

    output_file_content = null;
    jQuery('#output_formatted').empty();
    jQuery('#output_stats').empty();
    jQuery('#submit').html('<span class="fa fa-cog"></span> Waiting for Results <span class="fa fa-cog"></span>');
    jQuery('#submit').prop('disabled', true);
    jQuery.ajax('//quest.ms.mff.cuni.cz/ponk/api/process',
           {data: form_data ? form_data : options, processData: form_data ? false : true,
            contentType: form_data ? false : 'application/x-www-form-urlencoded; charset=UTF-8',
            dataType: "json", type: "POST", success: function(json) {
      try {
	  if ("result" in json) {
              output_file_content = json.result;
              //console.log("Found 'result' in return message:", output_file_content);
              displayFormattedOutput();
	  }
	  if ("stats" in json) {
              output_file_stats = json.stats;
              //console.log("Found 'stats' in return message:", output_file_stats);
              jQuery('#output_stats').html(output_file_stats);
	  }

      } catch(e) {
        jQuery('#submit').html('<span class="fa fa-arrow-down"></span> <?php echo $lang[$currentLang]['run_process_input']; ?> <span class="fa fa-arrow-down"></span>');
	jQuery('#submit').prop('disabled', false);
	//console.log("Caught an error!");
      }
    }, error: function(jqXHR, textStatus) {
      alert("An error occurred" + ("responseText" in jqXHR ? ": " + jqXHR.responseText : "!"));
    }, complete: function() {
      jQuery('#submit').html('<span class="fa fa-arrow-down"></span> <?php echo $lang[$currentLang]['run_process_input']; ?> <span class="fa fa-arrow-down"></span>');
      jQuery('#submit').prop('disabled', false);
      //console.log("All completed");
    }});
  }


  // Funkce pro kódování binárních dat do Base64
  function encodeBinaryToBase64(binaryData) {
    return btoa(String.fromCharCode.apply(null, new Uint8Array(binaryData)));
  }

  
  function getInfo() { // call the server and get the PONK version and a list of supported features

    var options = {info: null};
    //console.log("getInfo: options: ", options);

    var form_data = null;
    if (window.FormData) {
      form_data = new FormData();
      for (var key in options)
        form_data.append(key, options[key]);
    }

    var version = '<?php echo $lang[$currentLang]['run_server_info_version_unknown']; ?> (<font color="red"><?php echo $lang[$currentLang]['run_server_info_status_error']; ?>!</font>)';
    var features = '<?php echo $lang[$currentLang]['run_server_info_features_unknown']; ?>';
    //console.log("Calling api/info");
    jQuery.ajax('//quest.ms.mff.cuni.cz/ponk/api/info',
           {data: form_data ? form_data : options, processData: form_data ? false : true,
            contentType: form_data ? false : 'application/x-www-form-urlencoded; charset=UTF-8',
            dataType: "json", type: "POST", success: function(json) {
      try {
        if ("version" in json) {
		version = json.version;
		version += ', <span style="font-style: normal"><?php echo $lang[$currentLang]['run_server_info_status']; ?>:</span> <font color="green">online</font>';
		//console.log("json.version: ", version);
        }
        if ("features" in json) {
              features = json.features;
        }

      } catch(e) {
        // no need to do anything
      }
    }, error: function(jqXHR, textStatus) {
      console.log("An error occurred " + ("responseText" in jqXHR ? ": " + jqXHR.responseText : "!"));
    }, complete: function() {
      //console.log("Complete.");
      var info = "<h4><?php echo $lang[$currentLang]['run_server_info_label']; ?></h4>\n<ul><li><?php echo $lang[$currentLang]['run_server_info_version']; ?>: <i>" + version + "</i>\n<li><?php echo $lang[$currentLang]['run_server_info_features']; ?>: <i>" + features + "</i>\n</ul>\n";
      //console.log("Info: ", info);
      document.getElementById('server_info').innerHTML = info;
      document.getElementById('server_info').classList.remove('d-none');

      var short_info = "&nbsp; <?php echo $lang[$currentLang]['run_server_info_version']; ?>: <i>" + version + "</i>";
      //console.log("Short info: ", short_info);
      document.getElementById('server_short_info').innerHTML = short_info;
      document.getElementById('server_short_info').classList.remove('d-none');
      
    }});
  }
  
  function handleFileChange(input) {
    const inputName = document.getElementById('input_file_name');
    inputName.textContent = ''; // Clear previous content
    let input_file_content = null;

    if (input.files.length > 0) {
      const file = input.files[0];
      console.log("handleFileChange: input file name: ", `${file.name}`);
      inputName.textContent = `${file.name} (loading...)`;

      if (!window.FileReader) {
        inputName.textContent = `${file.name} (load error - file loading API not supported, please use newer browser)`;
        console.log("handleFileChange: load error - file loading API not supported");
        inputName.innerHTML = `<span class="text-danger">${inputName.textContent}</span>`;
      } else {
        const reader = new FileReader();
        console.log("handleFileChange: loading the file...");	      
        reader.onload = function(event) {
          const input_format = document.querySelector('input[name="option_input"]:checked').value;
          if (input_format === "docx") {
            input_file_content = encodeBinaryToBase64(event.target.result);
	  } else {
	    console.log("handleFileChange: the file is either TXT or MD");
            input_file_content = event.target.result;
          }
	  inputName.textContent = `${file.name} (${(input_file_content.length / 1024).toFixed(1)} KB)`;
	  console.log("handleFileChange: printing this: ", `${file.name} (${(input_file_content.length / 1024).toFixed(1)} KB)`);
        };

        reader.onerror = function() {
          inputName.textContent = `${file.name} (load error)`;
          inputName.innerHTML = `<span class="text-danger">${inputName.textContent}</span>`;
        };

        const input_format = document.querySelector('input[name="option_input"]:checked').value;
        if (input_format === "docx") {
          reader.readAsArrayBuffer(file);
        } else {
          reader.readAsText(file);
        }
      }
    }
  }

  function saveAs(blob, file_name) {
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = file_name;
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    window.URL.revokeObjectURL(url);
    document.body.removeChild(a);
  }

  function saveOutput() {
    if (!output_file_content || !output_format) return;
    var formatted_output = formatOutput();
    var content_blob = new Blob([formatted_output], {type: output_format == "html" ? "text/html" : "text/plain"});
    saveAs(content_blob, "citations." + output_format);
  }

  function saveStats() {
    if (!output_file_stats) return;
    var stats_blob = new Blob([output_file_stats], {type: "text/html"});
    saveAs(stats_blob, "statistics.html");
  }


  function formatOutput() { 
    var formatted_output = output_file_content;  
    // Nejprve checkbox pro zobrazování originálných výrazů
    //var checkbox = document.getElementById("origsCheckbox");
    //if (checkbox.checked) { // zobrazím původní výsledný text (vč. originálů)
    //  formatted_output = output_file_content;
    //} else { // vyhodím z výsledného textu originály
    //  formatted_output = removeOriginals(output_file_content);
    //}
    // Nyní checkbox pro barevné zvýraznění nových výrazů
    //checkbox = document.getElementById("highlightingCheckbox");
    //if (checkbox.checked) { // zobrazím původní výsledný text (vč. barevného zvýraznění)
      // nedělám nic
    //} else { // vyhodím z výsledného textu barevné zvýraznění nových výrazů
    //  formatted_output = removeHighlighting(formatted_output);
    //}
    return formatted_output;
  }


  function displayFormattedOutput() { // zobrazí output_file_content podle parametrů nastavených checkboxy
    //console.log("displayFormattedOutput: Entering the function");
    var formatted_output = formatOutput();
    // Přidání <br> ke každému novému řádku v proměnné with_or_without_origs
    var formatted_content = output_format == "html" ? formatted_output : formatted_output.replace(/\n/g, "\n<br>");
    //console.log("displayFormattedOutput: ", formatted_content);
    jQuery('#output_formatted').html(formatted_content);
  }


  //function handleOutputFormatChange() {
      //console.log("handleOutputFormatChange - entering the function");
  //    var txtRadio = document.getElementById("option_output_txt");
  //    var htmlRadio = document.getElementById("option_output_html");
  //    var checkbox = document.getElementById("highlightingCheckbox");

  //    if (txtRadio.checked) {
        // Zneaktivní checkbox při výběru TXT radio tlačítka
        //console.log("handleOutputFormatChange - disabling the checkbox");
  //      checkbox.disabled = true;
  //    } else if (htmlRadio.checked) {
  //      // Zaktivní checkbox při výběru HTML radio tlačítka
        //console.log("handleOutputFormatChange - enabling the checkbox");
  //      checkbox.disabled = false;
  //    }
  //}

  function handleInputFormatChange() {
      //console.log("handleInputFormatChange - entering the function");
      const radioInputDocx = document.getElementById('option_input_docx');
      const headerInputText = document.getElementById('input_text_header');
      const headerInputFile = document.getElementById('input_file_header');
      const tabInputText = document.getElementById('input_text');
      const tabInputFile = document.getElementById('input_file');

      if (radioInputDocx.checked) {
        headerInputText.classList.remove('active');
        tabInputText.classList.remove('active');
        //tabInputText.setAttribute('aria-selected', false);
        headerInputFile.classList.add('active');
        tabInputFile.classList.add('active');
        //tabInputFile.setAttribute('aria-selected', true);
      } 
  }

  function handleInputTextHeaderClicked() {
    //console.log("handleInputTextHeaderClicked - entering the function");
    const radioInputDocx = document.getElementById('option_input_docx');
    const radioInputTXT = document.getElementById('option_input_plaintext');
    if (radioInputDocx.checked) {
      radioInputDocx.checked = false;
      radioInputTXT.checked = true;
    }
  }


--></script>

  <!-- ================= ABOUT ================ -->

<div class="card">
  <div class="card-header" role="tab" id="aboutHeading">
    <button class="btn btn-link collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#aboutContent" aria-expanded="false" aria-controls="aboutContent">
      <i class="fa-solid fa-caret-down"></i> <?php echo $lang[$currentLang]['run_about_line']; ?>
    </button>
  </div>
  <div id="aboutContent" class="collapse m-1" role="tabpanel" aria-labelledby="aboutHeading">
          <?php
            if ($currentLang == 'cs') {
          ?>
    <div><?php require('about_cs.html') ?></div>
          <?php
            } else {
          ?>
    <div><?php require('about_en.html') ?></div>
          <?php
            }
          ?>
  </div>
</div>

  <!-- ================= SERVER INFO ================ -->

<div class="card">
  <div class="card-header" role="tab" id="serverInfoHeading">
    <button class="btn btn-link" type="button" data-bs-toggle="collapse" data-bs-target="#serverInfoContent" aria-expanded="false" aria-controls="serverInfoContent">
      <i class="fa-solid fa-caret-down" aria-hidden="true"></i> <?php echo $lang[$currentLang]['run_server_info_label']; ?>: <span id="server_short_info" class="d-none"></span>
    </button>
  </div>
  <div id="serverInfoContent" class="collapse m-1" role="tabpanel" aria-labelledby="serverInfoHeading">
      <div id="server_info" class="d-none"></div>

      <?php
      if ($currentLang == 'cs') {
      ?>
          <div><?php require('licence_cs.html'); ?></div>
      <?php
      } else {
      ?>
          <div><?php require('licence_en.html'); ?></div>
      <?php
      }
      ?>

      <p><?php echo $lang[$currentLang]['run_server_info_word_limit']; ?></p>
      <div id="error" class="alert alert-danger d-none"></div>
  </div>
</div>

  <!-- ================= OPTIONS ================ -->

<div class="row g-3 align-items-center">
  <div class="col-12 mb-3">
    <label class="form-label"><?php echo $lang[$currentLang]['run_options_input_label']; ?>:</label>
    <div class="form-check form-check-inline">
      <input class="form-check-input" type="radio" name="option_input" id="option_input_plaintext" value="txt" checked>
      <label class="form-check-label" for="option_input_plaintext" title="<?php echo $lang[$currentLang]['run_options_input_plain_popup']; ?>">
        <?php echo $lang[$currentLang]['run_options_input_plain']; ?>
      </label>
    </div>
    <div class="form-check form-check-inline">
      <input class="form-check-input" type="radio" name="option_input" id="option_input_markdown" value="md">
      <label class="form-check-label" for="option_input_markdown" title="<?php echo $lang[$currentLang]['run_options_input_md_popup']; ?>">
        <?php echo $lang[$currentLang]['run_options_input_md']; ?>
      </label>
    </div>
    <div class="form-check form-check-inline">
      <input class="form-check-input" type="radio" name="option_input" id="option_input_docx" value="docx" onchange="handleInputFormatChange();">
      <label class="form-check-label" for="option_input_docx" title="<?php echo $lang[$currentLang]['run_options_input_msworddocx_popup']; ?>">
        <?php echo $lang[$currentLang]['run_options_input_msworddocx']; ?>
      </label>
    </div>
  </div>

  <div class="col-12">
    <label class="form-label"><?php echo $lang[$currentLang]['run_options_output_label']; ?>:</label>
    <div class="form-check form-check-inline">
      <input class="form-check-input" type="radio" name="option_output" value="html" id="option_output_html" checked onchange="handleOutputFormatChange();">
      <label class="form-check-label" for="option_output_html" title="<?php echo $lang[$currentLang]['run_options_output_html_popup']; ?>">
        <?php echo $lang[$currentLang]['run_options_output_html']; ?>
        <!-- (<a href="http://ufal.mff.cuni.cz/ponk/users-manual#run_ponk_output" target="_blank">colour-marked</a>) -->
      </label>
    </div>
  </div>
</div>

<!-- ================= INPUT FIELDS ================ -->

<!-- ================ záložky panelů =============== -->
<ul class="nav nav-tabs nav-fill nav-tabs-green">
  <li class="nav-item" id="input_text_header">
    <div class="nav-link active d-flex justify-content-between align-items-center">
      <a href="#input_text" data-bs-toggle="tab" onclick="handleInputTextHeaderClicked();" class="mx-auto">
        <span class="fa fa-font"></span> <?php echo $lang[$currentLang]['run_input_text']; ?>
      </a>
      <button type="button" class="btn btn-primary btn-sm" onclick="var t=document.getElementById('input'); t.value=''; t.focus();">
        <?php echo $lang[$currentLang]['run_input_text_button_delete']; ?>
      </button>
    </div>
  </li>
  <li class="nav-item" id="input_file_header">
    <a class="nav-link" href="#input_file" data-bs-toggle="tab">
      <span class="fa fa-file-text-o"></span> <?php echo $lang[$currentLang]['run_input_file']; ?>
    </a>
  </li>
</ul>

<!-- ================ panely =============== -->
<div class="tab-content" id="input_tabs" style="border: 1px solid #ddd; border-radius: 0 0 .25rem .25rem; padding: 15px;">
  <div class="tab-pane show active" id="input_text">
    <textarea id="input" class="form-control" rows="10" cols="80"></textarea>
  </div>
  
  <div class="tab-pane" id="input_file">
    <div class="input-group">
      <input type="text" class="form-control" id="input_file_name" readonly>
      <label class="input-group-text btn btn-success btn-file" for="input_file_field"><?php echo $lang[$currentLang]['run_input_file_button_load']; ?> ...</label>
      <input type="file" id="input_file_field" class="visually-hidden" onchange="handleFileChange(this)">
    </div>
    <!--div class="input-group">
      <input type="text" class="form-control" id="input_file_name" readonly>
      <label class="input-group-text btn btn-success btn-file" for="input_file_field"><?php echo $lang[$currentLang]['run_input_file_button_load']; ?> ...</label>
      <input type="file" id="input_file_field" class="d-none">
    </div-->
  </div>
</div>

<!-- ================= THE PROCESS BUTTON ================ -->

<button id="submit" class="btn btn-primary form-control mt-3" type="submit" onclick="doSubmit()">
  <span class="fa fa-arrow-down"></span> <?php echo $lang[$currentLang]['run_process_input']; ?> <span class="fa fa-arrow-down"></span>
</button>

<!-- ================= OUTPUT FIELDS ================ -->

<!-- ================ záložky panelů =============== -->
<ul class="nav nav-tabs nav-fill nav-tabs-green">

  <li class="nav-item">
    <div class="nav-link active d-flex justify-content-between align-items-center">
      <a href="#output_formatted" data-bs-toggle="tab" class="mx-auto">
        <span class="fa fa-font"></span> <?php echo $lang[$currentLang]['run_output_text']; ?>
      </a>
      <button type="button" class="btn btn-primary btn-sm" onclick="saveOutput();">
        <span class="fa fa-download"></span> <?php echo $lang[$currentLang]['run_output_text_button_save']; ?> 
      </button>
    </div>
  </li>
  <li class="nav-item">
    <div class="nav-link d-flex justify-content-between align-items-center">
      <a href="#output_stats" data-bs-toggle="tab" class="mx-auto">
        <span class="fa fa-table"></span> <?php echo $lang[$currentLang]['run_output_statistics']; ?>
      </a>
      <button type="button" class="btn btn-primary btn-sm" onclick="saveStats();">
        <span class="fa fa-download"></span> <?php echo $lang[$currentLang]['run_output_statistics_button_save']; ?> 
      </button>
    </div>
  </li>
</ul>

<!-- ================ panely =============== -->
<div class="tab-content" id="output_tabs" style="border: 1px solid #ddd; border-radius: 0 0 .25rem .25rem; padding: 15px;">
  <div class="tab-pane fade show active" id="output_formatted"></div>
  <div class="tab-pane fade" id="output_stats"></div>
</div>


<!-- ================= ACKNOWLEDGEMENTS ================ -->

<div class="mt-3 mb-3">
  <?php
    if ($currentLang == 'cs') {
  ?>
    <div><?php include('acknowledgements_cs.html'); ?></div>
  <?php
    } else {
  ?>
    <div><?php include('acknowledgements_en.html'); ?></div>
  <?php
    }
  ?>
</div>

<?php require('footer.php') ?>
