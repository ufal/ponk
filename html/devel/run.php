<?php $main_page=basename(__FILE__); require('header.php') ?>

<script type="text/javascript"><!--
  var input_file_content = null;
  var output_file_content = null;
  var output_file_stats = null;
  var output_format = null;
  var app1_rule_info = null; // json converted to object with info about app1 rules
  var app1_stylesheet = null; // inline stylesheet for app1

  document.addEventListener("DOMContentLoaded", function() {
      getInfo();
      //console.log("DOM byl kompletně načten!");
  });

  document.addEventListener("DOMContentLoaded", function() {
      const textarea = document.getElementById('input');
      let originalValue = textarea.value;

      textarea.addEventListener('focus', function() {
          if (this.value === originalValue) {
              this.value = '';
              this.style.color = '#333333'; // Změní barvu na tmavou při psaní
          }
      });

      // Nastavení barvy pro předvyplněný text při načtení
      textarea.style.color = '#bbbbbb';
  });

  function toggleApp1Features() {
    //console.log("toggleApp1Features: Entering the function.");
    const featuresPanel = document.getElementById('features_app1');
    //const verticalTab = document.querySelector('.vertical-tab'); // Přidáno pro výběr vertikálního tabu
    const verticalTab = document.getElementById('features_app1_tab'); // Přidáno pro výběr vertikálního tabu
  
    if (featuresPanel.classList.toggle('show')) {
      verticalTab.classList.add('active');
    } else {
      verticalTab.classList.remove('active');
    }
  }

  function doSubmit() {
    //console.log("doSubmit: Entering the function.");
    var input_text;
    let activePanelId = getActivePanelID('#input_tabs');
    if (activePanelId) {
      console.log('Aktivní panel ID:', activePanelId);
    }
    if (activePanelId && activePanelId == 'input_file') { // input from a file
      if (!input_file_content) {
        alert('Please load a file first.'); return;
      }
      input_text = input_file_content;
      // console.log("doSubmit: Input text from a file: ", input_text);
    } else { // input as a directly entered text
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
    jQuery('#features_app1').empty();
    jQuery('#submit').html('<span class="fa fa-cog"></span> Waiting for Results <span class="fa fa-cog"></span>');
    jQuery('#submit').prop('disabled', true);

    jQuery.ajax('//quest.ms.mff.cuni.cz/ponk/api/process', {
      data: form_data ? form_data : options,
      processData: form_data ? false : true,
      contentType: form_data ? false : 'application/x-www-form-urlencoded; charset=UTF-8',
      dataType: "json",
      type: "POST",
      success: function(json) {
        try {
	  if ("result" in json) {
              output_file_content = json.result;
              //console.log("Found 'result' in return message:", output_file_content);
              displayFormattedOutput();
	  }
	  if ("app1_features" in json) {
              let output_app1_features = json.app1_features;
              //console.log("Found 'app1_features' in return message:", output_app1_features);
              jQuery('#features_app1').html(output_app1_features);
	  }
	  if ("app1_rule_info" in json) {
            // console.log("app1_rule_info found in JSON: ", json.app1_rule_info);
            let ruleInfo = json.app1_rule_info;
            // Kontrola, zda ruleInfo není string, pokud ano, pokus o parsování; bez toho to prostě nefungovalo.
            if (typeof ruleInfo === 'string') {
              try {
                ruleInfo = JSON.parse(ruleInfo);
              } catch (e) {
                console.error("Failed to parse app1_rule_info as JSON:", e);
              }
	    }
	    app1_rule_info = ruleInfo; // store the info to the global variable
	    applyApp1RuleInfoStyles(ruleInfo); // apply the styles to the web page
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


  function app1RuleCheckboxToggled(checkbox_id) {
    //console.log("app1RuleCheckboxToggled:", checkbox_id);
    let rule_name = checkbox_id.replace(/^check_app1_feature_/, '');
    //console.log("rule name: " + rule_name);
    let rule_class = 'app1_class_' + rule_name;
    let checkbox = document.getElementById(checkbox_id);
    // Kontrola, zda je checkbox zaškrtnutý
    if (checkbox.checked) {
      console.log("Checkbox je zaškrtnutý, class='" + rule_class + "'");

      if (app1_rule_info.hasOwnProperty(rule_name)) {
        console.log(`Key: ${rule_name}, Value:`, app1_rule_info[rule_name]);
        let rule = app1_rule_info[rule_name];
        if (typeof rule.foreground_color === 'object' && rule.foreground_color !== null) {
          let {red, green, blue} = rule.foreground_color;
          //console.log(`Key: ${rule_name}, RGB Color: rgb(${red}, ${green}, ${blue})`);
          let class_name = `app1_class_${rule_name}`;
          const colorStyle = 'rgb(' + Math.round(red) + ', ' + Math.round(green) + ', ' + Math.round(blue) + ') !important';
          //console.log('Red:', red, 'Green:', green, 'Blue:', blue);
          //console.log('Color Style:', colorStyle);
          let class_style = { 'color': colorStyle };
          createOrReplaceCSSClass(class_name, class_style);
          console.log(`Setting class ${class_name} to ${class_style} with color ${colorStyle}`); 
        } else {
          console.log(`Key: ${rule_name}, Foreground color not available or not an object.`);
        }
      }
    } else {
      //console.log("Checkbox není zaškrtnutý, class='" + rule_class + "'");
      removeCSSClass(rule_class);
    }
  }

  // given the object with app1_rule_info, it applies the styles to the web page
  function applyApp1RuleInfoStyles(ruleInfo) {
    // console.log("app1_rule_info:", ruleInfo);
    // Iterace přes klíče
    if (typeof ruleInfo === 'object' && ruleInfo !== null) {
      for (let key in ruleInfo) {
        if (ruleInfo.hasOwnProperty(key)) {
          console.log(`Key: ${key}, Value:`, ruleInfo[key]);
          let rule = ruleInfo[key];
          if (typeof rule.foreground_color === 'object' && rule.foreground_color !== null) {
            let {red, green, blue} = rule.foreground_color;
            //console.log(`Key: ${key}, RGB Color: rgb(${red}, ${green}, ${blue})`);
            let class_name = `app1_class_${key}`;
            const colorStyle = 'rgb(' + Math.round(red) + ', ' + Math.round(green) + ', ' + Math.round(blue) + ') !important';
            //console.log('Red:', red, 'Green:', green, 'Blue:', blue);
            //console.log('Color Style:', colorStyle);
            let class_style = { 'color': colorStyle };
            createOrReplaceCSSClass(class_name, class_style);
            console.log(`Setting class ${class_name} to ${class_style} with color ${colorStyle}`); 
          } else {
            console.log(`Key: ${key}, Foreground color not available or not an object.`);
          }
        }
      }
    } else {
      console.log("app1_rule_info is not an object or is null");
    }
  }


  // Dynamicky vloží definici css třídy do inline stylesheetu (pokud inline stylesheet neexistuje, je vytvořen).
  // Pokud daná css třída již je definována, její definice je nahrazena novou.
  // Example usage:
  /*createOrReplaceCSSClass('RuleLiteraryStyle', {
    'color': 'rgb(40, 200, 200)',
    'background-color': '#f0f0f0',
    'font-size': '16px'
  });*/

  function createOrReplaceCSSClass(className, properties) {
    console.log("createOrReplaceCSSClass: className='" + className + "'");

    // If no inline stylesheet for app1 exists, create one
    if (!app1_stylesheet) {
      const styleElement = document.createElement('style');
      styleElement.type = 'text/css';
      document.head.appendChild(styleElement);	    
      app1_stylesheet = styleElement.sheet; // set the global variable
    }

    // Convert properties object to CSS string
    const cssText = Object.entries(properties).map(([prop, value]) => 
        `${prop}:${value};`).join('');

    // Remove the rule if it already exists
    if (app1_stylesheet.cssRules) {
        for (let i = 0; i < app1_stylesheet.cssRules.length; i++) {
            if (app1_stylesheet.cssRules[i].selectorText === `.${className}`) {
                app1_stylesheet.deleteRule(i);
                break;
            }
        }
    }

    // Add the new or updated rule
    app1_stylesheet.insertRule(`.${className} { ${cssText} }`, app1_stylesheet.cssRules.length);
  }


  function removeCSSClass(className) {
    console.log("removeCSSClass: className='" + className + "'");
    if (!app1_stylesheet) {
      return;
    }
    let rules = app1_stylesheet.cssRules || app1_stylesheet.rules;
    // Iterate over all rules in the current stylesheet
    for (let i = 0; i < rules.length; i++) {
      if (rules[i].selectorText === `.${className}`) {
        // Remove the rule if it matches the className
        app1_stylesheet.deleteRule(i);
        console.log(`Removed CSS class: .${className}`);
        return; // Exit the function once the class is removed
      }
    }
    console.log(`CSS class .${className} not found or was already removed.`);
  }



  // funkce pro získání id aktivního panelu v dané sadě panelů
  // volat např. takto:
  // let activePanelId = getActivePanel('#input_tabs');
  // if (activePanelId) {
  //   console.log('Aktivní panel ID:', activePanelId);
  // }
  function getActivePanelID(containerSelector) {
      // Najdeme kontejner s panely
      let container = document.querySelector(containerSelector);
      if (!container) {
          console.error('Kontejner s panely nebyl nalezen: ', containerSelector);
          return null;
      }

      // Vybereme všechny tab-pane v rámci tohoto kontejneru
      let tabPanes = container.querySelectorAll('.tab-pane');

      // Najdeme ten, který má třídy 'show' a 'active'
      let activePane = Array.from(tabPanes).find(pane =>
          pane.classList.contains('show') && pane.classList.contains('active')
      );

      if (activePane) {
          // Získáme ID aktivního panelu
          // console.log('Aktivní panel je:', activePane.id);
          return activePane.id;
      } else {
          // console.log('Žádný panel není aktivní nebo kontejner neobsahuje aktivní panely.');
          return null;
      }
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


  // Reads an input file after it is selected by the user
  // The content is put in global variable input_file_content  
  function handleFileChange(input) {
    const inputName = document.getElementById('input_file_name');
    inputName.textContent = ''; // Clear previous content
    input_file_content = null;

    if (input.files.length > 0) {
      const file = input.files[0];
      console.log("handleFileChange: input file name: ", `${file.name}`);
      inputName.textContent = `${file.name} (loading...)`;

      if (!window.FileReader) {
        inputName.value = `${file.name} (load error - file loading API not supported, please use newer browser)`;
        console.log("handleFileChange: load error - file loading API not supported");
        inputName.innerHTML = `<span class="text-danger">${inputName.value}</span>`;
      } else {
        const input_format = document.querySelector('input[name="option_input"]:checked').value;
        const reader = new FileReader();
        console.log("handleFileChange: loading the file...");	      
        reader.onload = function(event) {
          console.log("handleFileChange: the set file format: ", input_format);
          if (input_format === "docx") {
	    console.log("handleFileChange: the file format is DOCX");
            //input_file_content = encodeBinaryToBase64(event.target.result);
            input_file_content = encodeBinaryToBase64(reader.result);
	  } else {
	    console.log("handleFileChange: the file format is either TXT or MD");
            //input_file_content = event.target.result;
	    input_file_content = reader.result;
	    //console.log("handleFileChange: input_file_content: ", input_file_content);
          }
	  inputName.value = `${file.name} (${(input_file_content.length / 1024).toFixed(1)} KB)`;
	  //console.log("handleFileChange: printing this: ", `${file.name} (${(input_file_content.length / 1024).toFixed(1)} KB)`);
        };

        reader.onerror = function() {
          inputName.value = `${file.name} (load error)`;
          inputName.innerHTML = `<span class="text-danger">${inputName.value}</span>`;
        };

	if (input_format === "docx") {
          console.log("handleFileChange: reader: reading file as array buffer (docx)");
          reader.readAsArrayBuffer(file);
        } else {
          console.log("handleFileChange: reader: reading file as text (txt or md)");
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
    const linkInputText = headerInputText.querySelector('a.nav-link');
    const linkInputFile = headerInputFile.querySelector('a.nav-link');

    if (radioInputDocx.checked) {
        // Nastavení tříd pro tab panely
        tabInputText.classList.remove('active', 'show');
        tabInputFile.classList.add('active', 'show');

        // Nastavení tříd pro přepínací záložky
        linkInputText.classList.remove('active');
        linkInputFile.classList.add('active');

        // Nastavení aria-selected atributů
        linkInputText.setAttribute('aria-selected', 'false');
        linkInputFile.setAttribute('aria-selected', 'true');

        // Trigger tab show for correct rendering in Bootstrap
        const tab = new bootstrap.Tab(linkInputFile);
        tab.show();
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
    const t=document.getElementById('input');
    //t.value='';
    t.focus();
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

<div class="row gx-2 gy-0 mt-lg-3 mb-lg-3">
  <div class="col-12 col-md-2 text-end">
    <label class="form-label fw-bold me-5"><?php echo $lang[$currentLang]['run_options_input_label']; ?>:</label>
  </div>
  <div class="col-12 col-md-10">
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

  <div class="col-12 col-md-2 text-end mt-0">
    <label class="form-label fw-bold me-5"><?php echo $lang[$currentLang]['run_options_output_label']; ?>:</label>
  </div>
  <div class="col-12 col-md-10 mt-0">
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

<!-- ================ záložky input panelů =============== -->
<ul class="nav nav-tabs nav-fill nav-tabs-green">
  <li class="nav-item position-relative" id="input_text_header">
    <a class="nav-link active" href="#input_text" data-bs-toggle="tab" onclick="handleInputTextHeaderClicked();">
      <span class="fa fa-font"></span> 
      <?php echo $lang[$currentLang]['run_input_text']; ?>
    </a>
    <!-- Tlačítko umístěné těsně u pravého okraje záložky -->
    <button class="btn btn-sm btn-primary btn-ponk-colors btn-ponk-small position-absolute" style="top: 10px; right: 10px; z-index: 1;" onclick="var t=document.getElementById('input'); t.value=''; t.focus();">
      <span class="fas fa-trash"></span> <?php echo $lang[$currentLang]['run_input_text_button_delete']; ?>
    </button>
  </li>
  <li class="nav-item" id="input_file_header">
    <a class="nav-link" href="#input_file" data-bs-toggle="tab">
      <span class="far fa-file-alt"></span> 
      <?php echo $lang[$currentLang]['run_input_file']; ?>
    </a>
  </li>
</ul>

<!-- ================ input panely =============== -->
<div class="tab-content" id="input_tabs" style="border: 1px solid #ddd; border-radius: 0 0 .25rem .25rem; padding: 15px;">
  <!--div class="tab-pane show active" id="input_text">
    <textarea id="input" class="form-control" rows="10" cols="80"></textarea>
  </div-->
<div class="tab-pane show active" id="input_text">
    <textarea id="input" class="form-control" rows="10" cols="80"><?php echo $lang['cs']['run_input_text_default_text']; ?></textarea>
</div>
  <div class="tab-pane" id="input_file">
    <div class="input-group">
      <input type="text" class="form-control" id="input_file_name" readonly>
      <label class="input-group-text btn btn-success btn-file" for="input_file_field"><?php echo $lang[$currentLang]['run_input_file_button_load']; ?> ...</label>
      <input type="file" id="input_file_field" class="visually-hidden" onchange="handleFileChange(this)">
    </div>
  </div>
</div>

<!-- ================= THE MAIN PROCESS BUTTON ================ -->

<button id="submit" class="btn btn-primary btn-ponk-colors form-control mt-3" type="submit" onclick="doSubmit()">
  <span class="fa fa-arrow-down"></span> <?php echo $lang[$currentLang]['run_process_input']; ?> <span class="fa fa-arrow-down"></span>
</button>

<!-- ================= OUTPUT FIELDS ================ -->

<!-- ================ záložky output panelů =============== -->
<ul class="nav nav-tabs nav-fill nav-tabs-green">

  <li class="nav-item position-relative">
    <a class="nav-link active" href="#output_panel" data-bs-toggle="tab">
      <span class="fa fa-font"></span> <?php echo $lang[$currentLang]['run_output_text']; ?>
    </a>
    <button class="btn btn-primary btn-sm btn-ponk-colors btn-ponk-small position-absolute" style="top: 10px; right: 10px; z-index: 1;" onclick="saveOutput();">
      <span class="fa fa-download"></span> <?php echo $lang[$currentLang]['run_output_text_button_save']; ?> 
    </button>
  </li>

  <li class="nav-item position-relative">
    <a class="nav-link" href="#output_stats" data-bs-toggle="tab">
      <span class="fa fa-table"></span> <?php echo $lang[$currentLang]['run_output_statistics']; ?>
    </a>
    <button class="btn btn-primary btn-sm btn-ponk-colors btn-ponk-small position-absolute" style="top: 10px; right: 10px; z-index: 1;" onclick="saveStats();">
      <span class="fa fa-download"></span> <?php echo $lang[$currentLang]['run_output_statistics_button_save']; ?> 
    </button>
  </li>

</ul>

<!-- ================ output panely =============== -->
<div class="tab-content" id="output_tabs" style="border: 1px solid #ddd; border-radius: 0 0 .25rem .25rem; padding: 15px;">

  <!-- ============ output panel se statistikami =========== -->
  <div class="tab-pane fade" id="output_stats"></div>

  <!-- ============ output panel s formátovaným textem, volbami po pravé straně a záložkou pro zobrazení těchto voleb =========== -->
  <div class="tab-pane fade show active" id="output_panel" style="overflow: visible;">
    <div class="d-flex align-items-stretch" style="height: 100%;">
      <div id="output_all" class="position-relative output-wrapper border border-muted rounded-start p-3 pe-0" style="flex: 1">
        <!-- ============ output panel s formátovaným textem =========== -->
        <div id="output_formatted" class="full-height"></div>
        <!-- ============ volby APP1 =========== -->
        <div id="features_app1" class="side-panel full-height border border-muted p-3 bg-light ms-3" style="position: absolute; right: 0; top: 0; height: 100%; background-color: white; z-index: 10; overflow-y: auto;"></div>
      </div>
      <!-- ============ záložka na pravé straně pro zobrazení/skrytí features_app1 =========== -->
      <div id="features_app1_tab" class="vertical-tab vertical-tab-green vertical-tab-right" onClick="toggleApp1Features();" style="width: 30px; display: flex; align-items: center; justify-content: center; cursor: pointer;">
        <span class="rotate-text">APP1 Features</span>
      </div>
    </div>
  </div>
 <!--div class="btn" onClick="createOrReplaceCSSClass('highlighted-text-app1', { 'color': 'red !important', 'font-size': '20px' });">POKUS</div-->
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
