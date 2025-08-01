<?php
$lang = array(
    'cs' => array(
        'menu_about' => 'O programu',
	'menu_run' => 'Spustit',
	'menu_api' => 'REST API',
	'run_about_line' => 'PONK je webový nástroj a služba REST API pro analýzu srozumitelnosti českých právních textů.',
	'run_server_info_word_limit' => 'Upozorňujeme, že vzhledem k časovým limitům našeho proxy serveru je maximální délka vstupního textu přibližně 5 tisíc slov.',
	'run_server_info_label' => 'Server',
	'run_server_info_version' => 'verze',
	'run_server_info_version_unknown' => 'neznámá',
	'run_server_info_status' => 'stav',
	'run_server_info_status_error' => 'server PONK je momentálně mimo provoz',
	'run_server_info_features' => 'podporované vlastnosti',
	'run_server_info_features_unknown' => 'neznámé',
	'run_options_input_label' => 'Vstup',
	'run_options_input_plain' => 'Prostý text',
	'run_options_input_plain_popup' => 'Vstupní formát: prostý text',
	'run_options_input_md' => 'Markdown',
	'run_options_input_md_popup' => 'Vstupní text ve formátu Markdown',
	'run_options_input_msworddocx' => 'Soubor MS Word .docx',
	'run_options_input_msworddocx_popup' => 'Vstup: soubor MS Word .docx',
	'run_options_output_label' => 'Výstup',
	'run_options_output_html' => 'HTML',
	'run_options_output_html_popup' => 'HTML s barevným zvýrazněním analýzy textu',
	'run_input_text' => 'Text',
	'run_input_text_default_text' => 'V případě, že uvidím psa, budu šťastný, ale v případě, že ho neuvidím, už nebudu. V důsledku čehož budu smutný. (Neuvidím psa a v důsledku toho budu smutný. Jestliže neuvidím psa, budu smutný, a poněvadž budu smutný, budeme všichni smutní.)',
	'run_input_text_button_delete' => 'Smazat',
	'run_input_file' => 'Soubor',
	'run_input_file_button_load' => 'Nahrát soubor',
	'run_input_file_kb_loaded_prefix' => 'nahráno ',
	'run_input_file_kb_loaded_suffix' => ' kb',
	'run_process_input' => 'Zpracovat',
	'run_process_input_processing' => 'Probíhá',
	'run_output_text' => 'Výstup',
	'run_output_text_button_save' => 'Uložit',
	'run_output_statistics' => 'Míry',
	'run_output_statistics_button_save' => 'Uložit',
	'run_output_app1_measures_label' => 'Míry textu jako celku',
	'run_output_app1_measures_info' => 'Barva pozadí v seznamu značí srozumitelnost celého textu vzhledem k dané míře. Zelená znamená v pořádku, oranžová značí průměr, červená znamená nízkou srozumitelnost.',
	'run_output_app1_measures_documentation' => '(Více informací v <a href=\"https://ufal.mff.cuni.cz/ponk/users-manual#web_interface_app1_measures\" target=\"_blank\">dokumentaci</a>.)',
	'run_output_app1' => 'Pravidla',
	'run_output_app1_rules_label' => 'Gramatická pravidla',
	'run_output_app1_rules_info' => 'Kliknutím můžete pravidlo zapnout či vypnout. Slova zasažená více aktivními pravidly mají šedivé pozadí.',
	'run_output_app1_rules_documentation' => '(Více informací v <a href=\"https://ufal.mff.cuni.cz/ponk/users-manual#web_interface_app1_rules\" target=\"_blank\">dokumentaci</a>.)',
	'run_output_app2' => 'Lex. př.',
	'run_output_app2_label' => 'Lexikální překvapení',
	'run_output_app2_info' => 'Barevný kód pro různé úrovně lexikálního překvapení. Kliknutím vyberete minimální úroveň pro zobrazení v textu.',
	'run_output_app2_documentation' => '(Více informací v <a href=\"https://ufal.mff.cuni.cz/ponk/users-manual#web_interface_app2\" target=\"_blank\">dokumentaci</a>.)',
	'info_basic_label' => 'Základní informace',
	'info_basic_authors' => 'Autoři',
	'info_basic_authors_subapplication' => 'podaplikace',
	'info_basic_authors_app1_label' => 'gramatická pravidla a celkové míry',
	'info_basic_authors_app2_label' => 'lexikální překvapení',
	'info_basic_homepage' => 'Domovská stránka',
	'info_basic_repository' => 'Vývojový repozitář',
	'info_basic_development_status' => 'Stav vývoje',
	'info_basic_development_status_development' => 'vývojová verze',
	'info_basic_OS' => 'OS',
	'info_basic_licence' => 'Licence',
	'info_basic_contact' => 'Kontakt',
	'api_service_url' => 'Rozhraní REST API k webové službě PONK je k dispozici na'
    ),
    'en' => array(
        'menu_about' => 'About',
	'menu_run' => 'Run',
	'menu_api' => 'REST API',
	'run_about_line' => 'PONK is an on-line tool and REST API service for analyzing readability of Czech legal texts.',
	'run_server_info_word_limit' => 'Please note that due to time limitations on our proxy server, the maximum length for input text is approximately 5 thousand words.',
	'run_server_info_label' => 'Server',
	'run_server_info_version' => 'version',
	'run_server_info_version_unknown' => 'unknown',
	'run_server_info_status' => 'status',
	'run_server_info_status_error' => 'the PONK server seems to be off-line',
	'run_server_info_features' => 'supported features',
	'run_server_info_features_unknown' => 'unknown',
	'run_options_input_label' => 'Input',
	'run_options_input_plain' => 'Plain text',
	'run_options_input_plain_popup' => 'Plain text input format',
	'run_options_input_md' => 'Markdown',
	'run_options_input_md_popup' => 'Markdown text input format',
	'run_options_input_msworddocx' => 'MS Word .docx file',
	'run_options_input_msworddocx_popup' => 'MS Word .docx file input',
	'run_options_output_label' => 'Output',
	'run_options_output_html' => 'HTML',
	'run_options_output_html_popup' => 'HTML with colour-encoded analysis of the text',
	'run_input_text' => 'Text',
	'run_input_text_default_text' => 'V případě, že uvidím psa, budu šťastný, ale v případě, že ho neuvidím, už nebudu. V důsledku čehož budu smutný. (Neuvidím psa a v důsledku toho budu smutný. Jestliže neuvidím psa, budu smutný, a poněvadž budu smutný, budeme všichni smutní.)',
	'run_input_text_button_delete' => 'Delete',
	'run_input_file' => 'File',
	'run_input_file_button_load' => 'Load File',
	'run_input_file_kb_loaded_prefix' => '',
	'run_input_file_kb_loaded_suffix' => 'kb loaded',
	'run_process_input' => 'Process',
	'run_process_input_processing' => 'Working',
	'run_output_text' => 'Output',
	'run_output_text_button_save' => 'Save',
	'run_output_statistics' => 'Measures',
	'run_output_statistics_button_save' => 'Save',
	'run_output_app1_measures_label' => 'Text-wide measures',
	'run_output_app1_measures_info' => 'The background colour in the list indicates the readibility of the whole text according to the given measure. Green means OK, orange means average, red means not good.',
	'run_output_app1_measures_documentation' => '(More info in <a href=\"https://ufal.mff.cuni.cz/ponk/users-manual#web_interface_app1_measures\" target=\"_blank\">documentation</a>.)',
	'run_output_app1' => 'Rules',
	'run_output_app1_rules_label' => 'Gramatical rules',
	'run_output_app1_rules_info' => 'Click to switch a rule on and off. Words involved in more than one active rule have a gray background.',
	'run_output_app1_rules_documentation' => '(More info in <a href=\"https://ufal.mff.cuni.cz/ponk/users-manual#web_interface_app1_rules\" target=\"_blank\">documentation</a>.)',
	'run_output_app2' => 'Lex. surp.',
	'run_output_app2_label' => 'Lexical surprise',
	'run_output_app2_info' => 'Colour code for various levels of lexical surprise. Click to choose a minimal level for displaying in the text.',
	'run_output_app2_documentation' => '(More info in <a href=\"https://ufal.mff.cuni.cz/ponk/users-manual#web_interface_app2\" target=\"_blank\">documentation</a>.)',
	'info_basic_label' => 'Basic info',
	'info_basic_authors' => 'Authors',
	'info_basic_authors_subapplication' => 'subapplication',
	'info_basic_authors_app1_label' => 'grammatical rules and overall measures',
	'info_basic_authors_app2_label' => 'lexical surprise',
	'info_basic_homepage' => 'Homepage',
	'info_basic_repository' => 'Development repository',
	'info_basic_development_status' => 'Development status',
	'info_basic_development_status_development' => 'development',
	'info_basic_OS' => 'OS',
	'info_basic_licence' => 'Licence',
	'info_basic_contact' => 'Contact',
	'api_service_url' => 'PONK REST API web service is available on'
    )
);
?>

