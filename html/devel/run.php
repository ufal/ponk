
<script type="text/javascript"><!--
  var input_file_content = null;
  var output_file_content = null;
  var output_file_stats = null;
  var output_format = null;
  var app1_rule_info = null; // json converted to object with info about app1 rules
  var app1_stylesheet = null; // inline stylesheet for app1 (rules)
  var app2_stylesheet = null; // inline stylesheet for app2 (lexical surprise)

  var app1_rule_active = {}; // an object ("hash") to keep info if individual rules are active
  var app1_ruleid_highlighted = []; // an array of actually highlighted classes rule_id (when hovering over a span in the results)
  
  var app1_token_ids = []; // an array of ids of tokens in the result (<span>) marked by app1


  // Inicializace Turndown pro převod html do markdownu
  const turndownService = new TurndownService();


  document.addEventListener("DOMContentLoaded", function() {
      getInfo();
      //console.log("DOM byl kompletně načten!");
  });

  document.addEventListener("DOMContentLoaded", function() {
      const text_input = document.getElementById('input');
      let originalValue = text_input.innerHTML;

      text_input.addEventListener('focus', function() {
          if (this.innerHTML === originalValue) {
              this.innerHTML = '';
          }
      });
  });

  // Calling the SERVER:

  function doSubmit() {
    //console.log("doSubmit: Entering the function.");
    app1_rule_active = {}; // forget previous app1 rules activity statuses
    var input_text;

    var input_format = jQuery('input[name=option_input]:checked').val();
    //console.log("doSubmit: Input format: ", input_format);

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
      //input_text = jQuery('#input').val();
      const editablePanel = document.getElementById('input');

           
      if (input_format === "txt") {
        input_text = editablePanel.innerText; // Pouze text bez formátování
        //console.log("doSubmit: Input plain text: ", input_text);
      } else {
        let input_text_html = editablePanel.innerHTML; // Plný HTML obsah
        //console.log("doSubmit: Input html before testing html tag: ", input_text_html);
        if (isHTML(input_text_html)) { // tzn. už zpracováváme dříve vrácenou html odpověď: html převedeme na MarkDown
          console.log("doSubmit: Input html: ", input_text_html);
          input_text = turndownService.turndown(input_text_html);
          console.log("doSubmit: Input html as markdown: ", input_text);
        }
	else { // ručně vložený MarkDown
          input_text = editablePanel.innerText;
          console.log("doSubmit: Input MarkDown text: ", input_text);
	}
      }

      // Odstranění obsahu <style> !!! je to ještě potřeba?
      input_text = input_text.replace(/\/\*[\s\S]*?\*\/|\.[\w-]+\s*{[^}]*}/g, '').trim();
    }

    //var input_text = jQuery('#input').val();
    //console.log("doSubmit: Input text: ", input_text);
    output_format = jQuery('input[name=option_output]:checked').val();
    //console.log("doSubmit: Output format: ", output_format);

          <?php
            if ($currentLang == 'cs') {
          ?>
            var ui_lang = 'cs'; 
          <?php
            } else {
          ?>
            var ui_lang = 'en'; 
          <?php
            }
          ?>

    var internal_apps = "app1,app2";
    var options = {text: input_text, input: input_format, output: output_format, uilang: ui_lang, apps: internal_apps};
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
    //jQuery('#output_formatted').empty();
    jQuery('#output_stats').empty();
    jQuery('#features_app1').empty();
    jQuery('#features_app2').empty();
    //jQuery('#submit').html('<span class="fa fa-cog"></span>&nbsp;<?php echo $lang[$currentLang]['run_process_input_processing']; ?>&nbsp;<span class="fa fa-cog"></span>');
    jQuery('#submit').html('<span class="spinner-border spinner-border-sm" style="width: 1.2rem; height: 1.2rem;" role="status" aria-hidden="true"></span>&nbsp;<?php echo $lang[$currentLang]['run_process_input_processing']; ?>&nbsp;<span class="spinner-border spinner-border-sm" style="width: 1.2rem; height: 1.2rem; animation-direction: reverse;" role="status" aria-hidden="true"></span>');
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
            var full_html = json.result;
            //console.log("doSubmit: Found 'result' in return message:", full_html);
            output_file_content = getBodyContent(full_html).trim();
            //console.log("doSubmit: Only trimmed 'body' content of 'result':", output_file_content);
            app1_token_ids = getSpanIds(output_file_content);
            //console.log("App1 token ids: ", app1_token_ids);
            const editablePanel = document.getElementById('input');
            editablePanel.innerHTML = output_file_content;
            //console.log("doSubmit: New innerHTML of input: ", editablePanel.innerHTML);
            displayFormattedOutput();
	  }

          console.log("Looking for app1_features");
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
	    highlightTokensWithMultipleActiveApp1Rules();
	  }

	  if ("app2_colours" in json) {
            let app2_colours_json_string = json.app2_colours;
	    //console.log("Found 'app2_colours' in return message:", app2_colours_json_string);
	    let app2_colours_html = generateApp2ColoursTable(app2_colours_json_string);
	    jQuery('#features_app2').html(app2_colours_html);
	    generateApp2Stylesheet(app2_colours_json_string);
	  }
          console.log("Going to check features_app1 tab\n");
	  if (isTabActive('features_app1')) {
            console.log("Going to activate app1_stylesheet\n");
            toggleStylesheet('app1_stylesheet', 1);
            console.log("Going to disactivate app2_stylesheet\n");
            toggleStylesheet('app2_stylesheet', 0);
          }
          console.log("... after checking features_app1 tab\n");
          console.log("Going to check features_app2 tab\n");
	  if (isTabActive('features_app2')) {
            console.log("Going to activate app2_stylesheet\n");
            toggleStylesheet('app2_stylesheet', 1);
            console.log("Going to disactivate app1_stylesheet\n");
            toggleStylesheet('app1_stylesheet', 0);
          }
          console.log("... after checking features_app2 tab\n");

	  if ("stats" in json) {
              output_file_stats = json.stats;
              //console.log("Found 'stats' in return message:", output_file_stats);
              jQuery('#output_stats').html(output_file_stats);
	  }

      } catch(e) {
        jQuery('#submit').html('<span class="fa fa-arrow-down"></span>&nbsp;<?php echo $lang[$currentLang]['run_process_input']; ?>&nbsp;<span class="fa fa-arrow-down"></span>');
        jQuery('#submit').prop('disabled', false);
        //console.log("doSubmit: Caught an error!");
      }
    }, error: function(jqXHR, textStatus) {
      alert("An error occurred" + ("responseText" in jqXHR ? ": " + jqXHR.responseText : "!"));
    }, complete: function() {
      jQuery('#submit').html('<span class="fa fa-arrow-down"></span>&nbsp;<?php echo $lang[$currentLang]['run_process_input']; ?>&nbsp;<span class="fa fa-arrow-down"></span>');
      jQuery('#submit').prop('disabled', false);
      // přepnutí na panel s textem:
      const tabElement = document.querySelector('a[href="#input_text"]');
      const tab = new bootstrap.Tab(tabElement);
      tab.show();
      //console.log("All completed");
    }});
  }


  function isTabActive(panelId) {
    try {
        // Najít <a> element s href="#panelId"
        const tabLink = document.querySelector(`a.nav-link[href="#${panelId}"]`);
        
        // Pokud odkaz neexistuje, vrátit 0
        if (!tabLink) {
            console.error(`Odkaz pro panel s ID ${panelId} nebyl nalezen`);
            return 0;
        }
        
        // Zkontrolovat, zda má odkaz třídu active
        return tabLink.classList.contains('active') ? 1 : 0;
    } catch (error) {
        console.error('Chyba při kontrole aktivního panelu:', error);
        return 0;
    }
  }


  function featuresApp1Activated() {
    console.log("Going to activate app1_stylesheet\n");
    toggleStylesheet('app1_stylesheet', 1);
    console.log("Going to disactivate app2_stylesheet\n");
    toggleStylesheet('app2_stylesheet', 0);
  }

  function featuresApp2Activated() {
    console.log("Going to activate app2_stylesheet\n");
    toggleStylesheet('app2_stylesheet', 1);
    console.log("Going to disactivate app1_stylesheet\n");
    toggleStylesheet('app1_stylesheet', 0);
  }

  // Aktivuje (při activate === 1) či deaktivuje daný stylesheet (app1_stylesheet či app2_stylesheet)
  function toggleStylesheet(stylesheetName, activate) {
    try {

        // Najít cílový stylesheet
        const targetStyleElement = document.getElementById(stylesheetName);
        if (!targetStyleElement) {
            console.error(`Stylesheet s ID ${stylesheetName} nebyl nalezen`);
            return;
        }

        // Nastavit disabled vlastnost cílového stylesheetu
        targetStyleElement.disabled = (activate === 0);

    } catch (error) {
        console.error('Chyba při přepínání stylesheetu:', error);
    }
  }


  // Funkce pro detekci, zda text začíná <html>
  function isHTML(text) {
    return /^\s*<html/i.test(text); // Ignoruje mezery na začátku a je case-insensitive
  }


  function getBodyContent(htmlString) {
    // Použijeme DOMParser k parsování HTML řetězce
    const parser = new DOMParser();
    const doc = parser.parseFromString(htmlString, 'text/html');

    // Vrátíme obsah elementu <body>
    return doc.body.innerHTML;
  }


  // Převede JSON s definicí barev app2 na html tabulku
  function generateApp2ColoursTable(jsonString) {
    try {
        // Parsování JSON řetězce na objekt
        const data = JSON.parse(jsonString);
        
        // Extrakce klíčů a seřazení numericky
        const sortedKeys = Object.keys(data).sort((a, b) => Number(a) - Number(b));
        
        // Vytvoření HTML tabulky
        let html = '<table style="width: 100%; border-collapse: collapse;">';
        
        // Generování řádků pro každý klíč
        sortedKeys.forEach(key => {
            const backgroundColor = data[key];
            html += `<tr>
                        <td style="background-color: ${backgroundColor}; width: 100%; padding: 3px; text-align: center; line-height: 1.2; font-size: 0.8rem">
                            ${key}
                        </td>
                    </tr>`;
        });
        
        html += '</table>';
        
        return html;
    } catch (error) {
        console.error('Chyba při parsování JSON:', error);
        return '<p>Chyba při generování tabulky: Neplatný JSON formát</p>';
    }
  }	
	
	
	
  // vrátí pole id z elementů span v daném html kódu
  function getSpanIds(html) {
    let parser = new DOMParser();
    let doc = parser.parseFromString(html, "text/html");
    
    // Vybereme všechny span elementy a vytvoříme pole jejich id
    let spanIds = Array.from(doc.querySelectorAll('span')).map(span => span.id);
    
    return spanIds;
  }


  // projde pole app1_token_ids a zvýrazní barevným pozadím příslušné tokeny, které jsou zasaženy více než jedním aktivním app1 pravidlem
  // aktivní pravidla mají hodnotu 1 v hashi app1_rule_active
  function highlightTokensWithMultipleActiveApp1Rules() {
    // Projít všechny id v globální proměnné app1_token_ids
    console.log("Entering highlightTokens...");
    app1_token_ids.forEach(id => {
        const element = document.getElementById(id);
	if (element) {
            // Filtr tříd, které začínají na 'app1_class_' a nemají další podtržítko za nimi
            const validClasses = Array.from(element.classList).filter(className => {
                // Získání části třídy bez prefixu 'app1_class_'
                if (className.startsWith('app1_class_') && className.indexOf('_', 'app1_class_'.length) === -1) {
                    const ruleName = className.slice('app1_class_'.length);
                    // Zkontrolování, zda je ruleName v app1_rule_active s hodnotou 1
                    return app1_rule_active[ruleName] === 1;
                }
                return false;
            });

            // Filtr tříd, které začínají na 'app1_class_' a nemají další podtržítko za nimi
            //const validClasses = Array.from(element.classList).filter(className => 
            //    className.startsWith('app1_class_') && 
            //    className.indexOf('_', 'app1_class_'.length) === -1
            //);
            
            // Pokud má element alespoň dvě platné třídy, nastavit žluté pozadí
            if (validClasses.length >= 2) {
              element.style.backgroundColor = '#c2c2c2';
              //element.style.color = 'black';   
            } else {
                // Jinak odstranit nastavení pozadí
                element.style.backgroundColor = '';
            }
        }
    });
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
        app1_rule_active[rule_name] = 1; // store the info on activity status of this rule
        if (typeof rule.foreground_color === 'object' && rule.foreground_color !== null) {
          let {red, green, blue} = rule.foreground_color;
          //console.log(`Key: ${rule_name}, RGB Color: rgb(${red}, ${green}, ${blue})`);
          let class_name = `app1_class_${rule_name}`;
          const colorStyle = 'rgb(' + Math.round(red) + ', ' + Math.round(green) + ', ' + Math.round(blue) + ') !important';
          //console.log('Red:', red, 'Green:', green, 'Blue:', blue);
          //console.log('Color Style:', colorStyle);
          //let class_style = { 'color': colorStyle, 'font-weight': 'bold' };
          let class_style = { 'color': colorStyle, 'text-shadow': '0.02em 0 0 currentColor, -0.02em 0 0 currentColor' };
          createOrReplaceCSSClass(class_name, class_style);
          console.log(`Setting class ${class_name} to ${class_style} with color ${colorStyle}`); 
        } else {
          console.log(`Key: ${rule_name}, Foreground color not available or not an object.`);
        }
      }
    } else {
      //console.log("Checkbox není zaškrtnutý, class='" + rule_class + "'");
      removeCSSClass(rule_class);
      app1_rule_active[rule_name] = 0; // store the info on activity status of this rule
    }
    highlightTokensWithMultipleActiveApp1Rules();
  }

  // given the object with app1_rule_info, it applies the styles to the web page
  function applyApp1RuleInfoStyles(ruleInfo) {
    // console.log("app1_rule_info:", ruleInfo);
    // Iterace přes klíče
    if (typeof ruleInfo === 'object' && ruleInfo !== null) {
      for (let key in ruleInfo) {
        if (ruleInfo.hasOwnProperty(key)) {
          //console.log(`Key: ${key}, Value:`, ruleInfo[key]);
	  let rule = ruleInfo[key];
	  app1_rule_active[key] = 1;
	  //console.log(`Setting key ${key} activity status to 1`);
          if (typeof rule.foreground_color === 'object' && rule.foreground_color !== null) {
            let {red, green, blue} = rule.foreground_color;
            //console.log(`Key: ${key}, RGB Color: rgb(${red}, ${green}, ${blue})`);
            let class_name = `app1_class_${key}`;
            const colorStyle = 'rgb(' + Math.round(red) + ', ' + Math.round(green) + ', ' + Math.round(blue) + ') !important';
            //console.log('Red:', red, 'Green:', green, 'Blue:', blue);
            //console.log('Color Style:', colorStyle);
            //let class_style = { 'color': colorStyle, 'font-weight': 'bold' };
            let class_style = { 'color': colorStyle, 'text-shadow': '0.02em 0 0 currentColor, -0.02em 0 0 currentColor' };
            createOrReplaceCSSClass(class_name, class_style);
            //console.log(`Setting class ${class_name} to ${class_style} with color ${colorStyle}`); 
          } else {
            //console.log(`Key: ${key}, Foreground color not available or not an object.`);
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
      styleElement.id = 'app1_stylesheet';
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


  function generateApp2Stylesheet(jsonString) {
    // If no inline stylesheet for app2 exists, create one
    if (!app2_stylesheet) {
      const styleElement = document.createElement('style');
      styleElement.id = 'app2_stylesheet';
      styleElement.type = 'text/css';
      document.head.appendChild(styleElement);      
      app2_stylesheet = styleElement.sheet; // set the global variable
    }
    try {
        // Parsování JSON řetězce na objekt
        const data = JSON.parse(jsonString);
        
        // Vytvoření CSS pravidel
        let css = '';
        
        // Generování třídy pro každý klíč
        for (const key in data) {
            if (data.hasOwnProperty(key)) {
                const backgroundColor = data[key];
                css += `.app2_class_${key} { background-color: ${backgroundColor}; }\n`;
            }
        }
        
        // Nastavit obsah <style> elementu
        const styleElement = document.getElementById('app2_stylesheet');
        styleElement.textContent = css;
    } catch (error) {
        console.error('Chyba při parsování JSON:', error);
        // Nastavit chybovou zprávu do <style> elementu
        const styleElement = document.getElementById('app2_stylesheet');
        styleElement.textContent = '/* Chyba při generování stylesheetu: Neplatný JSON formát */';
    }
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


  // given a rule name (e.g., RuleLiteraryStyle), it adds bold font to its class in the inline stylesheet
  function app1RuleHoverStart(app1_rule) {
    //console.log("app1RuleHoveStart with rule name", app1_rule);
    let ruleIndex = Array.from(app1_stylesheet.cssRules).findIndex(rule => rule.selectorText === '.app1_class_' + app1_rule);
    if (ruleIndex !== -1) {
        let rule = app1_stylesheet.cssRules[ruleIndex];
	//rule.style.fontWeight = 'bold';
	//rule.style.fontSize = '1.2em';
	//rule.style.textDecoration = 'underline';
	//rule.style.textDecorationStyle = 'wavy';
	//rule.style.border = '1px solid black';
	rule.style.borderTop = '2px solid black'; // Tlustší horní čára
        //rule.style.borderRight = '1px solid black'; // Tenčí boční čára
        rule.style.borderBottom = '2px solid black'; // Tlustší dolní čára
        //rule.style.borderLeft = '1px solid black'; // Tenčí boční čára
	rule.style.borderRadius = '2px'; // Hodnotu můžeš upravit podle toho, jak kulaté rohy chceš
	rule.style.padding = '0px'; // Padding můžeš upravit podle potřeby
        //rule.style.marginLeft = '-1px';
	rule.style.display = 'inline';
	rule.style.outline = '1px solid black';
	rule.style.outlineOffset = '-1px';
    } else {
      console.log("No class definition for", app1_rule);
    }
  }

  // given a rule name (e.g., RuleLiteraryStyle), it sets normal font to its class in the inline stylesheet
  function app1RuleHoverEnd(app1_rule) {
    //console.log("app1RuleHoveEnd with rule name", app1_rule);
    let ruleIndex = Array.from(app1_stylesheet.cssRules).findIndex(rule => rule.selectorText === '.app1_class_' + app1_rule);
    if (ruleIndex !== -1) {
        let rule = app1_stylesheet.cssRules[ruleIndex];
	//rule.style.fontWeight = 'normal';
	//rule.style.fontSize = '1.0em';
	//rule.style.textDecoration = 'none';
	//rule.style.textDecorationStyle = 'solid';
	rule.style.border = 'none';
	rule.style.borderRadius = '0';
        rule.style.padding = '0';
	//rule.style.marginLeft = '0';
	rule.style.outline = 'none';
    } else {
      console.log("No class definition for", app1_rule);
    }
  }


  // given a text piece in the result (a span element), it highlights the element and all other elements with the same active rule+id class
  function app1SpanHoverStart(element) {
    console.log("app1SpanHoveStart; classes: ");
    app1_ruleid_highlighted = [];
    var classes = element.classList;
    for(var i = 0; i < classes.length; i++) {
      var class_name = classes[i];
      console.log(class_name);
      let withoutPrefix = class_name.replace("app1_class_", "");
      let parts = withoutPrefix.split('_');
      if (parts.length > 1) {
        let rule = parts[0]; // "RuleVerbalNouns"
        let id = parts[1];   // "1e938644"

        console.log(rule);  // Výstup: RuleVerbalNouns
	console.log(id);    // Výstup: 1e938644
	if (app1_rule_active[rule]) {
          console.log(" - rule active!");
	  createOrReplaceCSSClass(class_name, {
	    //'box-shadow': '1px 2px 1px 2px black',
            'outline': '1px solid black',
            'outline-offset': '-1px',
            'padding': '0',
            'display': 'inline',
            'border-top': '2px solid black',
            'border-bottom': '2px solid black',
            //'border-left': '1px solid black',
            //'border-right': '1px solid black',
            'border-radius': '2px'
	  })
          app1_ruleid_highlighted.push(class_name);
	}
      }
    }
  }

  function app1SpanHoverEnd(element) {
    console.log("app1SpanHoverEnd; removing classes: ");
    for(var i = 0; i < app1_ruleid_highlighted.length; i++) {
      var ruleid = app1_ruleid_highlighted[i];
      console.log(ruleid);
      removeCSSClass(ruleid);
    }
    app1_ruleid_highlighted = [];
  }

  // funkce pro získání id aktivního panelu v dané sadě panelů
  // volat např. takto:
  // let activePanelId = getActivePanel('#output_tabs');
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

      //var short_info = "&nbsp; <?php echo $lang[$currentLang]['run_server_info_version']; ?>: <i>" + version + "</i>";
      var short_info = "<i>" + version + "</i>";
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
        inputName.value = `${file.name} (load error - file loading API not supported, please use a newer browser)`;
        console.log("handleFileChange: load error - file loading API not supported");
        inputName.innerHTML = `<span class="text-danger">${inputName.value}</span>`;
      } else {
	t=document.getElementById('input'); t.innerHTML=''; // smaž případný předchozí ručně vložený text
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

  //function saveOutput() {
  //  if (!output_file_content || !output_format) return;
  //  var formatted_output = formatOutput();
  //  var content_blob = new Blob([formatted_output], {type: output_format == "html" ? "text/html" : "text/plain"});
  //  saveAs(content_blob, "ponk." + output_format);
  //}

  function saveOutput() {
  // Kontrola, zda je definován output_format
  //if (!output_format) return;

  var output_format = "html";
  console.log("saveOutput");
  // Získání aktuálního HTML obsahu z <div id="input">
  var inputDiv = document.getElementById('input');
  var formatted_output = inputDiv.innerHTML;

  // Formátování obsahu (pokud je funkce formatOutput() potřeba, jinak přeskočte)
  //formatted_output = formatOutput(formatted_output);

  // Vytvoření Blob podle formátu
  var content_blob = new Blob([formatted_output], { type: output_format === "html" ? "text/html" : "text/plain" });

  // Uložení souboru
  saveAs(content_blob, "ponk." + output_format);
}

  //function saveStats() {
  //  if (!output_file_stats) return;
  //  var stats_blob = new Blob([output_file_stats], {type: "text/html"});
  //  saveAs(stats_blob, "statistics.html");
  //}

  function deleteAll() {
    var inputDiv = document.getElementById('input');
    inputDiv.innerHTML = '';
    inputDiv.focus();
    document.getElementById('output_stats').innerHTML = '';
    document.getElementById('features_app1').innerHTML = '';
    document.getElementById('features_app2').innerHTML = '';
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
    const t=document.getElementById('input');
    t.innerHTML=formatted_content;
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
    //t.innerHTML='';
    t.focus();
  }


--></script>


<!-- ================= INPUT FIELDS ================ -->

<div class="container-fluid border rounded px-0 mt-1" style="height: 80vh;">
  <div class="row gx-2 h-100">

<!-- Levá část (2/3 šířky) -->
<div class="col-md-8 d-flex flex-column h-100">
  <!-- Záložky levé části -->
  <ul class="nav nav-tabs nav-tabs-green nav-tabs-custom nav-fill">
    <li class="nav-item" id="input_text_header">
      <a class="nav-link active d-flex align-items-center" href="#input_text" data-bs-toggle="tab" onclick="handleInputTextHeaderClicked();">
        <span class="fa fa-font me-2"></span>
        <span><?php echo $lang[$currentLang]['run_input_text']; ?></span>
        <div class="ms-auto d-flex gap-2">
          <button class="btn btn-sm btn-primary btn-ponk-colors btn-ponk-small" onclick="deleteAll(); event.stopPropagation();">
            <span class="fas fa-trash"></span>
          </button>
          <button class="btn btn-primary btn-sm btn-ponk-colors btn-ponk-small" onclick="saveOutput(); event.stopPropagation();">
            <span class="fa fa-download"></span>
          </button>
        </div>
      </a>
    </li>
    <li class="nav-item">
      <button id="submit" class="nav-link btn btn-primary btn-ponk-colors d-flex align-items-center justify-content-center w-100 text-white" type="submit" onclick="doSubmit()">
        <span class="fa fa-arrow-down me-2"></span>
        <span><?php echo $lang[$currentLang]['run_process_input']; ?></span>
        <span class="fa fa-arrow-down ms-2"></span>
      </button>
    </li>
    <li class="nav-item" id="input_file_header">
      <a class="nav-link" href="#input_file" data-bs-toggle="tab">
        <span class="far fa-file-alt"></span> 
        <?php echo $lang[$currentLang]['run_input_file']; ?>
      </a>
    </li>
  </ul>

<div class="tab-content flex-grow-1" id="input_tabs" style="border: 1px solid #ddd; border-radius: .25rem; height: 100vh; max-height: 100vh; overflow: hidden;">
  <div class="tab-pane fade show active h-100" id="input_text" style="height: 100%; max-height: 100%;">
    <div id="input" contenteditable="true" class="p-3 h-100" style="height: 100%; max-height: 100%; overflow-y: auto; box-sizing: border-box;" spellcheck="true" lang="cs">
      <span style="color: #bbbbbb"><?php echo $lang[$currentLang]['run_input_text_default_text']; ?></span>
    </div>
  </div>
  <div class="tab-pane fade h-100" id="input_file" style="height: 100%; max-height: 100%;">
    <!-- Přepínače formátu vstupu -->
    <div class="d-flex align-items-center ms-2 mt-3 mb-2" style="font-size: 0.9rem;">
      <label class="form-label fw-bold me-3"><?php echo $lang[$currentLang]['run_options_input_label']; ?>:</label>
      <div class="d-flex gap-3">
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
    </div>
    <!-- Vstup pro soubor -->
    <div class="input-group mb-2">
      <input type="text" class="form-control" id="input_file_name" readonly>
      <label class="input-group-text btn btn-success btn-file" for="input_file_field"><?php echo $lang[$currentLang]['run_input_file_button_load']; ?> ...</label>
      <input type="file" id="input_file_field" class="visually-hidden" onchange="handleFileChange(this)">
    </div>
  </div>
</div>

</div>

<!-- Pravá část (1/3 šířky) -->
<div class="col-md-4 d-flex flex-column h-100">
  <!-- Záložka pro pravou část -->
  <ul class="nav nav-tabs nav-fill nav-tabs-green nav-tabs-custom nav-fill">
    <li class="nav-item">
      <a class="nav-link d-flex align-items-center" href="#output_stats" data-bs-toggle="tab">
        <span><?php echo $lang[$currentLang]['run_output_statistics']; ?></span>
      </a>
    </li>
    <li class="nav-item">
      <a class="nav-link active d-flex align-items-center" href="#features_app1" data-bs-toggle="tab" onclick="featuresApp1Activated()">
        <span><?php echo $lang[$currentLang]['run_output_app1']; ?></span>
      </a>
    </li>
    <li class="nav-item">
      <a class="nav-link d-flex align-items-center" href="#features_app2" data-bs-toggle="tab" onclick="featuresApp2Activated()">
        <span><?php echo $lang[$currentLang]['run_output_app2']; ?></span>
      </a>
    </li>
  </ul>

  <!-- Panely pro pravou část -->
  <div class="tab-content flex-grow-1" id="output_tabs" style="border: 1px solid #ddd; border-radius: .25rem; padding: 15px; overflow-y: auto;">
    <div class="tab-pane fade h-100" id="output_stats" style="width: 100%;"></div>
    <div id="features_app1" class="tab-pane active show fade h-100" style="width: 100%; white-space: normal; word-wrap: break-word;"></div>
    <div id="features_app2" class="tab-pane fade h-100" style="width: 100%;"></div>
  </div>
</div>

  </div>
</div>

