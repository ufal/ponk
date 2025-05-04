
<?php
// Spuštění session pro uchovávání jazyka mezi požadavky
session_start();

// Změna jazyka přes GET parametr
if (isset($_GET['lang']) && $_GET['lang'] !== $_SESSION['lang']) {
    $_SESSION['lang'] = $_GET['lang'];
    
    // Získání aktuální URL bez lang parametru
    $baseUrl = '/ponk';
    $currentUrlWithoutLang = preg_replace('/(\?|&)lang=[^&]*/', '', $_SERVER['REQUEST_URI']);
    
    // Přesměrování na URL bez lang parametru
    header("Location: " . $baseUrl . $currentUrlWithoutLang);
    exit();
}

// Nastavení defaultního jazyka, pokud není nastavený
if (!isset($_SESSION['lang'])) {
    $_SESSION['lang'] = 'cs'; // Defaultní jazyk je český
}

// Načtení jazykového souboru
require 'lang.php';

// Uložení aktuálního jazyka do proměnné pro snadnější použití
$currentLang = $_SESSION['lang'];
?>

<!DOCTYPE html>
<html>
<head>
  <title>PONK</title>
  <meta charset="utf-8">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.6.0/css/all.min.css"> <!-- Aktualizovaná verze Font Awesome -->
  <link rel="stylesheet" href="css/lindat.css" type="text/css" />
  <link rel="stylesheet" href="css/ponk.css" type="text/css" />

  <script src="https://code.jquery.com/jquery-1.11.3.min.js" type="text/javascript"></script>
  <!-- Bootstrap 5 JavaScript, nyní bez jQuery -->
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
  <script src="https://cdn.rawgit.com/google/code-prettify/master/loader/run_prettify.js" type="text/javascript"></script>
  <!-- Načtení Turndown pro konverzi html do markdownu -->
  <script src="https://unpkg.com/turndown/dist/turndown.js"></script>
</head>

<body id="lindat-services">
  <div class="lindat-common">
    <div class="container">
      <!-- Service title a menu vedle sebe -->
      <div class="d-flex align-items-end justify-content-between pt-lg-3">
        <!-- Nápis PONK -->
        <img src="img/PONK.png" height="65px" style="padding-bottom: 5px; padding-top: 0px; padding-left: 2px">

        <!-- Server info (pouze na run.php) -->
        <?php if ($main_page == 'run.php') { ?>
          <div class="server-info-header mx-3">
            <div class="card-header" role="tab" id="serverInfoHeading" style="padding: 0.2rem 1rem; min-height: unset; background: none; border: none;">
              <button class="btn btn-link" type="button" data-bs-toggle="collapse" data-bs-target="#serverInfoContent" aria-expanded="false" aria-controls="serverInfoContent" style="padding: 0.2rem 0.5rem; font-size: 0.9rem; text-decoration: none;">
                <i class="fa-solid fa-caret-down" aria-hidden="true" style="font-size: 0.8rem;"></i> <?php echo $lang[$currentLang]['run_server_info_label']; ?>: <span id="server_short_info" class="d-none"></span>
              </button>
            </div>
          </div>
        <?php } ?>

        <!-- Menu a vlaječka -->
        <div class="d-flex align-items-center">
          <!-- Menu -->
          <div class="menu-container position-relative">
            <ul class="nav nav-tabs nav-tabs-gray mb-0">
              <li class="nav-item">
                <a class="nav-link <?php if ($main_page == 'info.php') echo 'active'; ?>" href="info.php">
                  <span class="fa fa-info-circle"></span> <?php echo $lang[$currentLang]['menu_about']; ?>
                </a>
              </li>
              <li class="nav-item">
                <a class="nav-link <?php if ($main_page == 'run.php') echo 'active'; ?>" href="run.php">
                  <span class="fa fa-cogs"></span> <?php echo $lang[$currentLang]['menu_run']; ?>
                </a>
              </li>
              <li class="nav-item">
                <a class="nav-link <?php if ($main_page == 'api-reference.php') echo 'active'; ?>" href="api-reference.php">
                  <span class="fa fa-list"></span> <?php echo $lang[$currentLang]['menu_api']; ?>
                </a>
              </li>
            </ul>
          </div>

          <!-- Vlaječka odděleně -->
          <div class="ms-3">
            <?php
              if ($currentLang == 'cs') {
            ?>
                <a href="?lang=en" class="nav-link p-0">
                  <img src="img/flag_en.png" alt="English" style="height: 18px;">
                </a>
            <?php
              } else {
            ?>
                <a href="?lang=cs" class="nav-link p-0">
                  <img src="img/flag_cs.png" alt="čeština" style="height: 18px;">
                </a>
            <?php
              }
            ?>
          </div>
        </div>
      </div>

      <!-- Rozbalovací panel (pouze na run.php, přes celou šířku) -->
      <?php if ($main_page == 'run.php') { ?>
        <div id="serverInfoContent" class="collapse mt-2" role="tabpanel" aria-labelledby="serverInfoHeading">
          <div class="card">
            <div class="card-body">
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
        </div>
      <?php } ?>
