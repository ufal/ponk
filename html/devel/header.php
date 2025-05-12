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
<html style="scroll-behavior: auto;">
<head>
  <title>PONK</title>
  <meta charset="utf-8">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.6.0/css/all.min.css">
  <link rel="stylesheet" href="css/lindat.css" type="text/css" />
  <link rel="stylesheet" href="css/ponk.css" type="text/css" />

  <script src="https://code.jquery.com/jquery-3.6.0.min.js" type="text/javascript"></script>
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
  <script src="https://cdn.rawgit.com/google/code-prettify/master/loader/run_prettify.js" type="text/javascript"></script>
  <script src="https://unpkg.com/turndown/dist/turndown.js"></script>
</head>

<body id="lindat-services">
  <div class="lindat-common">
    <div class="container">
      <!-- Service title a menu vedle sebe -->
      <div class="d-flex align-items-end justify-content-between pt-lg-3">
        <!-- Nápis PONK -->
        <img src="img/PONK.png" height="65px" style="padding-bottom: 5px; padding-top: 0px; padding-left: 2px">

        <!-- Server info (zobrazeno pouze pro Run tab) -->
        <div class="server-info-header mx-3" id="serverInfoHeader" style="display: none;">
          <div class="card-header" role="tab" id="serverInfoHeading" style="padding: 0.2rem 1rem; min-height: unset; background: none; border: none;">
            <button class="btn btn-link" type="button" data-bs-toggle="collapse" data-bs-target="#serverInfoContent" aria-expanded="false" aria-controls="serverInfoContent" style="padding: 0.2rem 0.5rem; font-size: 0.9rem; text-decoration: none;">
              <i class="fa-solid fa-caret-down" aria-hidden="true" style="font-size: 0.8rem;"></i> <?php echo $lang[$currentLang]['run_server_info_label']; ?>: <span id="server_short_info" class="d-none"></span>
            </button>
          </div>
        </div>

        <!-- Menu a vlaječka -->
        <div class="d-flex align-items-center">
          <!-- Menu -->
          <div class="menu-container position-relative">
            <ul class="nav nav-tabs nav-tabs-gray mb-0" id="mainTabs">
              <li class="nav-item">
                <a class="nav-link" href="#info" data-bs-toggle="tab" role="tab" aria-controls="info">
                  <span class="fa fa-info-circle"></span> <?php echo $lang[$currentLang]['menu_about']; ?>
                </a>
              </li>
              <li class="nav-item">
                <a class="nav-link active" href="#run" data-bs-toggle="tab" role="tab" aria-controls="run">
                  <span class="fa fa-cogs"></span> <?php echo $lang[$currentLang]['menu_run']; ?>
                </a>
              </li>
              <li class="nav-item">
                <a class="nav-link" href="#api" data-bs-toggle="tab" role="tab" aria-controls="api">
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

      <!-- Rozbalovací panel pro server info -->
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

  <!-- JavaScript pro zobrazení server info a správu tabu -->
  <script type="text/javascript">
    document.addEventListener('DOMContentLoaded', function() {
      const mainTabs = document.querySelector('#mainTabs');
      const serverInfoHeader = document.querySelector('#serverInfoHeader');
      const serverInfoContent = document.querySelector('#serverInfoContent');

      function updateServerInfoVisibility() {
        const runTab = document.querySelector('#run');
        if (runTab && runTab.classList.contains('active')) {
          serverInfoHeader.style.display = 'block';
        } else {
          serverInfoHeader.style.display = 'none';
          serverInfoContent.classList.remove('show');
        }
      }

      // Spustit při načtení stránky
      updateServerInfoVisibility();

      // Sledovat změnu tabu a zabránit scrollování
      mainTabs.querySelectorAll('a[data-bs-toggle="tab"]').forEach(tab => {
        tab.addEventListener('click', function(e) {
          e.preventDefault(); // Zabránit defaultnímu scrollování
          new bootstrap.Tab(this).show();
        });
        tab.addEventListener('shown.bs.tab', updateServerInfoVisibility);
      });

      // Zpracování URL hash při načtení stránky bez scrollování
      if (window.location.hash) {
        const hash = window.location.hash;
        console.log('Processing hash:', hash);
        if (['#info', '#run', '#api'].includes(hash)) {
          const tabLink = mainTabs.querySelector(`a[href="${hash}"]`);
          if (tabLink) {
            console.log('Activating tab:', hash);
            new bootstrap.Tab(tabLink).show();
            // Zabránit scrollování k tab-content
            window.scrollTo({ top: 0, behavior: 'auto' });
          } else {
            console.error('Tab link not found for hash:', hash);
          }
        }
      }

      // Aktualizovat hash při změně tabu bez scrollování
      mainTabs.querySelectorAll('a[data-bs-toggle="tab"]').forEach(tab => {
        tab.addEventListener('shown.bs.tab', function(e) {
          history.replaceState(null, null, e.target.getAttribute('href')); // Aktualizovat hash bez scrollování
          console.log('Tab switched to:', e.target.getAttribute('href'));
        });
      });

      // Event delegation pro odkazy v about_en.html a about_cs.html
      document.addEventListener('click', function(e) {
        const link = e.target.closest('a[href="#info"], a[href="#run"], a[href="#api"]');
        if (link) {
          e.preventDefault(); // Zabránit defaultnímu scrollování
          const targetId = link.getAttribute('href');
          console.log('Link clicked:', targetId);
          const tabLink = mainTabs.querySelector(`a[href="${targetId}"]`);
          if (tabLink) {
            console.log('Switching to tab:', targetId);
            new bootstrap.Tab(tabLink).show();
            window.scrollTo({ top: 0, behavior: 'auto' }); // Udržet stránku nahoře
          } else {
            console.error('Tab link not found for:', targetId);
          }
        }
      });
    });
  </script>
