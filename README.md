dictionary
==========

dictionary.com has great service: thesaurus.com. Re-envisioned Thesaurus.com contains the first modern update to any thesaurus in over 160 years. It provides users with over 1,000 modern synonyms and a suite of helpful features and tools found only at Thesaurus.com to help people find the perfect word.

## Install

1. Clone the `dictionary` repository to some directory:

	```elisp
	$ git clone https://github.com/Levenson/dictionary.git /path/to/dictionary/directory
	```

2. Add to `.emacs.el` (or equivalent):

	```elisp
	(add-to-list 'load-path "/path/to/dictionary/directory")
	(require 'dictionary)

	(global-set-key (kbd "C-c h d") 'dictionary-helm-thesaurus-lookup)
	```

## Usage

Find word you want to check, use `dictionary-helm-thesaurus-lookup` function. Through the helm source find appropriate synonym or antonym and press enter. The new synonym will be inserted right after your cursor.
