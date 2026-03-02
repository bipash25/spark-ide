import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Maps file extensions and names to Symbols SVG icons.
///
/// Uses the "Symbols" icon theme by Miguel Solorio (MIT licensed).
/// SVGs are located in assets/icons/files/ and assets/icons/folders/.
class FileIconService {
  const FileIconService._();

  static const String _filesDir = 'assets/icons/files';
  static const String _foldersDir = 'assets/icons/folders';
  static const String _defaultFileIcon = 'document';
  static const String _defaultFolderIcon = 'folder';

  /// Get an SVG icon widget for a file by name.
  static Widget getFileIcon(String fileName, {double size = 16}) {
    final iconName = _resolveFileIcon(fileName);
    return SvgPicture.asset(
      '$_filesDir/$iconName.svg',
      width: size,
      height: size,
    );
  }

  /// Get an SVG icon widget for a folder by name.
  static Widget getFolderIcon(String folderName, {double size = 16}) {
    final iconName = _resolveFolderIcon(folderName);
    return SvgPicture.asset(
      '$_foldersDir/$iconName.svg',
      width: size,
      height: size,
    );
  }

  /// Get the SVG asset path for a file icon.
  static String getFileIconPath(String fileName) {
    final iconName = _resolveFileIcon(fileName);
    return '$_filesDir/$iconName.svg';
  }

  /// Get the SVG asset path for a folder icon.
  static String getFolderIconPath(String folderName) {
    final iconName = _resolveFolderIcon(folderName);
    return '$_foldersDir/$iconName.svg';
  }

  // ── Resolution logic ──────────────────────────────────────────────

  static String _resolveFileIcon(String fileName) {
    final lower = fileName.toLowerCase();

    // 1. Exact filename match
    final byName = _fileNames[lower];
    if (byName != null) return byName;

    // 2. Multi-part extension match (e.g. "d.ts", "test.js", "stories.tsx")
    //    Try progressively shorter suffixes: "spec.test.js" → "test.js" → "js"
    final parts = lower.split('.');
    if (parts.length > 2) {
      for (int i = 1; i < parts.length - 1; i++) {
        final multiExt = parts.sublist(i).join('.');
        final byMultiExt = _fileExtensions[multiExt];
        if (byMultiExt != null) return byMultiExt;
      }
    }

    // 3. Simple extension match
    final dotIndex = lower.lastIndexOf('.');
    if (dotIndex >= 0 && dotIndex < lower.length - 1) {
      final ext = lower.substring(dotIndex + 1);
      final byExt = _fileExtensions[ext];
      if (byExt != null) return byExt;
    }

    return _defaultFileIcon;
  }

  static String _resolveFolderIcon(String folderName) {
    final lower = folderName.toLowerCase();
    return _folderNames[lower] ?? _defaultFolderIcon;
  }

  // ══════════════════════════════════════════════════════════════════
  //  Extension → Icon definition name
  //  (from symbol-icon-theme.json "fileExtensions")
  // ══════════════════════════════════════════════════════════════════

  static const Map<String, String> _fileExtensions = {
    // TypeScript declaration files
    'd.ts': 'ts-types',
    'd.cts': 'ts-types',
    'd.mts': 'ts-types',

    // Angular compound extensions
    'component.dart': 'angular-component',
    'component.ts': 'angular-component',
    'component.js': 'angular-component',
    'service.dart': 'angular-service',
    'service.ts': 'angular-service',
    'service.js': 'angular-service',
    'directive.dart': 'angular-directive',
    'directive.ts': 'angular-directive',
    'directive.js': 'angular-directive',
    'module.dart': 'angular-module',
    'module.ts': 'angular-module',
    'module.js': 'angular-module',
    'guard.dart': 'angular-guard',
    'guard.ts': 'angular-guard',
    'guard.js': 'angular-guard',
    'pipe.dart': 'angular-pipe',
    'pipe.ts': 'angular-pipe',
    'pipe.js': 'angular-pipe',

    // Test file extensions
    'test.mjs': 'js-test',
    'spec.mjs': 'js-test',
    'test.js': 'js-test',
    'spec.js': 'js-test',
    'test.ts': 'ts-test',
    'spec.ts': 'ts-test',
    'spec.jsx': 'react-test',
    'test.jsx': 'react-test',
    'spec.tsx': 'react-test',
    'test.tsx': 'react-test',

    // Redux
    'actions.ts': 'redux-actions',
    'effects.ts': 'redux-effects',
    'facade.ts': 'redux-facade',
    'reducer.ts': 'redux-reducer',
    'selector.ts': 'redux-selector',
    'selectors.ts': 'redux-selector',

    // Storybook
    'stories.js': 'storybook',
    'stories.jsx': 'storybook',
    'stories.mdx': 'storybook',
    'story.js': 'storybook',
    'story.jsx': 'storybook',
    'stories.ts': 'storybook',
    'stories.tsx': 'storybook',
    'story.ts': 'storybook',
    'story.tsx': 'storybook',
    'stories.svelte': 'storybook',

    // Svelte TS
    'svelte.ts': 'svelte-ts',

    // Dart
    'freezed.dart': 'dart',
    'g.dart': 'dart',

    // Laravel
    'blade.php': 'laravel',

    // Twig
    'html.twig': 'twig',

    // Statamic
    'antlers.html': 'statamic-antlers',

    // Go module
    'go.mod': 'go-mod',

    // YAML dist
    'yml.dist': 'yaml',
    'yaml.dist': 'yaml',
    'YAML-tmLanguage': 'yaml',

    // XML dist
    'xml.dist': 'xml',
    'xml.dist.sample': 'xml',

    // Terraform
    'tf.json': 'terraform',

    // VS filter files
    'vcxitems.filters': 'visual-studio',
    'vcxproj.filters': 'visual-studio',

    // ── Simple extensions ────────────────────────────────────────

    // Dart
    'dart': 'dart',

    // JavaScript / TypeScript
    'js': 'js',
    'mjs': 'js',
    'cjs': 'js',
    'ts': 'ts',
    'jsx': 'react',
    'tsx': 'react-ts',

    // Python
    'py': 'python',
    'python': 'python',

    // Web
    'html': 'code-orange',
    'htm': 'code-orange',
    'shtml': 'code-orange',
    'css': 'brackets-purple',
    'scss': 'sass',
    'sass': 'sass',
    'less': 'less',
    'svg': 'svg',
    'vue': 'vue',
    'svelte': 'svelte',
    'astro': 'astro',

    // C / C++ / Obj-C
    'c': 'c',
    'i': 'c',
    'mi': 'c',
    'h': 'h',
    'cc': 'cplus',
    'cpp': 'cplus',
    'cxx': 'cplus',
    'c++': 'cplus',
    'cp': 'cplus',
    'mm': 'cplus',
    'mii': 'cplus',
    'ii': 'cplus',
    'cu': 'cuda',
    'cuh': 'cuda',

    // C# / .NET
    'cs': 'csharp',
    'csx': 'csharp',
    'cshtml': 'razor',
    'csproj': 'visual-studio',
    'sln': 'visual-studio',
    'slnx': 'visual-studio',
    'vb': 'visual-studio',
    'vbs': 'visual-studio',

    // Java / Kotlin
    'java': 'java',
    'jsp': 'java',
    'kt': 'kotlin',
    'kts': 'kotlin',
    'gradle': 'gradle',

    // Go
    'go': 'go',

    // Rust
    'rs': 'rust',
    'ron': 'rust',

    // Ruby
    'rb': 'ruby',
    'erb': 'ruby',

    // PHP
    'php': 'php',

    // Swift
    'swift': 'swift',

    // Shell / Terminal
    'sh': 'shell',
    'ksh': 'shell',
    'csh': 'shell',
    'tcsh': 'shell',
    'zsh': 'shell',
    'bash': 'shell',
    'nu': 'shell',
    'bat': 'shell',
    'cmd': 'shell',
    'awk': 'shell',
    'fish': 'shell',
    'exp': 'shell',
    'ps1': 'shell',
    'psm1': 'shell',
    'psd1': 'shell',
    'ps1xml': 'shell',
    'psc1': 'shell',
    'pssc': 'shell',
    'ssh_config': 'shell',

    // Data / Config
    'json': 'brackets-yellow',
    'yaml': 'yaml',
    'yml': 'yaml',
    'xml': 'xml',
    'plist': 'xml',
    'xsd': 'xml',
    'dtd': 'xml',
    'xsl': 'xml',
    'xslt': 'xml',
    'resx': 'xml',
    'iml': 'xml',
    'xquery': 'xml',
    'tmLanguage': 'xml',
    'manifest': 'xml',
    'project': 'xml',
    'dmn': 'xml',
    'toml': 'gear',
    'env': 'gear',
    'csv': 'csv',
    'xlsx': 'csv',
    'xlsm': 'csv',
    'xls': 'csv',
    'tsv': 'csv',
    'psv': 'csv',
    'ods': 'csv',

    // SQL / Database
    'sql': 'database',
    'pdb': 'database',
    'pks': 'database',
    'pkb': 'database',
    'accdb': 'database',
    'mdb': 'database',
    'sqlite': 'database',
    'sqlite3': 'database',
    'pgsql': 'database',
    'postgres': 'database',
    'psql': 'database',
    'db': 'database',
    'db3': 'database',
    'mongodb': 'mongo',

    // Markdown / Docs
    'md': 'markdown',
    'mdx': 'mdx',
    'txt': 'text',
    'htaccess': 'document',

    // PDF
    'pdf': 'pdf',

    // Images
    'png': 'image',
    'jpeg': 'image',
    'jpg': 'image',
    'ico': 'image',
    'tif': 'image',
    'tiff': 'image',
    'psd': 'image',
    'bmp': 'image',
    'webp': 'image',
    'avif': 'image',
    'heif': 'image',
    'heic': 'image',
    'gif': 'gif',

    // Video
    'mp4': 'video',
    'webm': 'video',
    'mkv': 'video',
    'avi': 'video',
    'mov': 'video',
    'wmv': 'video',
    'flv': 'video',
    'mpg': 'video',
    'mpeg': 'video',
    'm4v': 'video',

    // Audio
    'mp3': 'audio',
    'flac': 'audio',
    'm4a': 'audio',
    'wma': 'audio',
    'aiff': 'audio',
    'wav': 'audio',

    // Font
    'woff': 'font',
    'woff2': 'font',
    'ttf': 'font',
    'eot': 'font',
    'otf': 'font',

    // Archives / Binary
    'exe': 'exe',
    'msi': 'exe',
    'lock': 'lock',

    // Notebook
    'ipynb': 'notebook',

    // Scala / SBT
    'scala': 'scala',
    'sc': 'scala',
    'sbt': 'sbt',

    // R
    'r': 'r',
    'rmd': 'r',

    // Lua
    'lua': 'lua',
    'luau': 'luau',

    // Perl
    'pl': 'perl',

    // Elixir
    'ex': 'elixir',
    'exs': 'elixir',
    'eex': 'elixir',
    'leex': 'elixir',
    'heex': 'elixir',

    // Haskell
    'hs': 'haskell',

    // OCaml
    'ml': 'ocaml',
    'mli': 'ocaml',

    // F#
    'fs': 'fsharp',
    'fsx': 'fsharp',
    'fsi': 'fsharp',
    'fsproj': 'fsharp',

    // Julia
    'jl': 'julia',

    // Crystal
    'cr': 'crystal',

    // Clojure
    'clj': 'clojure',

    // Erlang
    'erl': 'erlang',
    'hrl': 'erlang',

    // Nim
    'nim': 'nim',

    // Zig
    'zig': 'zig',

    // V
    'v': 'v',

    // Nix
    'nix': 'nix',

    // Fortran
    'f90': 'fortran',
    'f95': 'fortran',
    'f03': 'fortran',
    'f': 'fortran',
    'for': 'fortran',

    // Solidity
    'sol': 'solidity',

    // GraphQL
    'graphql': 'graphql',
    'gql': 'graphql',

    // Prisma
    'prisma': 'prisma',

    // Proto
    'proto': 'proto',

    // Terraform
    'tf': 'terraform',
    'tfvars': 'terraform',
    'tfstate': 'terraform',

    // TeX
    'tex': 'tex',
    'sty': 'tex',
    'dtx': 'tex',
    'ltx': 'tex',

    // Docker
    'dockerignore': 'docker',
    'dockerfile': 'docker',
    'containerignore': 'docker',

    // Stylus
    'styl': 'stylus',

    // PostCSS
    'pcss': 'postcss',
    'sss': 'postcss',

    // Pug
    'jade': 'pug',
    'pug': 'pug',

    // CoffeeScript
    'coffeescript': 'coffeescript',

    // Haml
    'haml': 'haml',

    // Liquid
    'liquid': 'liquid',

    // Twig
    'twig': 'twig',

    // Nunjucks
    'njk': 'nunjucks',
    'nunjucks': 'nunjucks',

    // Drawio
    'drawio': 'drawio',
    'dio': 'drawio',

    // Patch
    'patch': 'patch',

    // HTTP
    'http': 'http',
    'rest': 'http',
    'bru': 'http',

    // ReScript
    'res': 'rescript',
    'resi': 'rescript-interface',

    // Pkl
    'pkl': 'pkl',

    // CMake
    'cmake': 'cmake',

    // i18n
    'lang': 'i18n',
    'mo': 'i18n',
    'po': 'i18n',
    'pot': 'i18n',

    // Gleam
    'gleam': 'gleam',

    // CUDA
    'cuda': 'cuda',

    // Coldfusion
    'cfml': 'coldfusion',
    'cfc': 'coldfusion',
    'lucee': 'coldfusion',
    'cfm': 'coldfusion',

    // Misc
    'svx': 'svx',
    'editorconfig': 'editorconfig',
    'test': 'code-orange',
    'vsixmanifest': 'puzzle',
    'vsix': 'puzzle',
    'al': 'code-green',
    'cls': 'code-blue',

    // Func
    'fc': 'func',
  };

  // ══════════════════════════════════════════════════════════════════
  //  Exact filename → Icon definition name
  //  (from symbol-icon-theme.json "fileNames", deduplicated)
  // ══════════════════════════════════════════════════════════════════

  static const Map<String, String> _fileNames = {
    // Git
    '.gitignore': 'git',
    '.gitignore-global': 'git',
    '.gitignore_global': 'git',
    '.gitconfig': 'git',
    '.gitattributes': 'git',
    '.gitmodules': 'git',
    '.gitkeep': 'git',
    '.gitinclude': 'git',
    '.git-blame-ignore': 'git',
    'git-history': 'git',

    // Ignore
    '.vscodeignore': 'ignore',

    // Docker
    'dockerfile': 'docker',
    'dockerfile.prod': 'docker',
    'dockerfile.production': 'docker',
    'dockerfile.dev': 'docker',
    'dockerfile.development': 'docker',
    'dockerfile.local': 'docker',
    'dockerfile.test': 'docker',
    'dockerfile.testing': 'docker',
    'dockerfile.ci': 'docker',
    'dockerfile.stage': 'docker',
    'dockerfile.staging': 'docker',
    'dockerfile.alpha': 'docker',
    'dockerfile.beta': 'docker',
    'dockerfile.web': 'docker',
    'dockerfile.worker': 'docker',
    'docker-compose.yml': 'docker-pink',
    'docker-compose.yaml': 'docker-pink',
    'docker-compose.override.yml': 'docker-pink',
    'docker-compose.override.yaml': 'docker-pink',
    'docker-compose.prod.yml': 'docker-pink',
    'docker-compose.prod.yaml': 'docker-pink',
    'docker-compose.dev.yml': 'docker-pink',
    'docker-compose.dev.yaml': 'docker-pink',
    'docker-compose.local.yml': 'docker-pink',
    'docker-compose.local.yaml': 'docker-pink',
    'docker-compose.test.yml': 'docker-pink',
    'docker-compose.test.yaml': 'docker-pink',
    'compose.yml': 'docker-pink',
    'compose.yaml': 'docker-pink',
    'compose.dev.yml': 'docker-pink',
    'compose.dev.yaml': 'docker-pink',
    'compose.prod.yml': 'docker-pink',
    'compose.prod.yaml': 'docker-pink',
    'docker-healthcheck': 'docker-green',

    // Firebase
    'firebase.json': 'firebase',
    '.firebaserc': 'firebase',
    'firestore.rules': 'firebase',
    'firestore.indexes.json': 'firebase',

    // License
    'license': 'license',
    'license.md': 'license',
    'license.txt': 'license',
    'license.rst': 'license',
    'license-mit': 'license',
    'license-apache': 'license',
    'license-gpl': 'license',

    // Node / NPM / Yarn / PNPM / Bun
    'package.json': 'node',
    'package-lock.json': 'node',
    '.nvmrc': 'node',
    '.esmrc': 'node',
    '.node-version': 'node',
    '.npmignore': 'npm',
    '.npmrc': 'npm',
    'yarn.lock': 'yarn',
    'yarn': 'yarn',
    'pnpm-lock.yaml': 'pnpm',
    'pnpm-workspace.yaml': 'pnpm',
    '.pnpmfile.cjs': 'pnpm',
    'bun.lock': 'bun',
    'bun.lockb': 'bun',
    'bunfig.toml': 'bun',

    // TypeScript config
    'tsconfig.json': 'tsconfig',
    'tsconfig.app.json': 'tsconfig',
    'tsconfig.base.json': 'tsconfig',
    'tsconfig.build.json': 'tsconfig',
    'tsconfig.node.json': 'tsconfig',
    'tsconfig.lib.json': 'tsconfig',
    'tsconfig.spec.json': 'tsconfig',
    'tsconfig.eslint.json': 'tsconfig',
    'tsconfig.test.json': 'ts-test',

    // ESLint
    'eslint.config.js': 'eslint',
    'eslint.config.cjs': 'eslint',
    'eslint.config.mjs': 'eslint',
    'eslint.config.ts': 'eslint',
    '.eslintrc.js': 'eslint',
    '.eslintrc.cjs': 'eslint',
    '.eslintrc.json': 'eslint',
    '.eslintrc.yaml': 'eslint',
    '.eslintrc.yml': 'eslint',
    '.eslintrc': 'eslint',
    '.eslintignore': 'eslint',
    '.eslintcache': 'eslint',

    // Prettier
    '.prettierrc': 'prettier',
    '.prettierrc.json': 'prettier',
    '.prettierrc.js': 'prettier',
    '.prettierrc.cjs': 'prettier',
    '.prettierrc.mjs': 'prettier',
    '.prettierrc.yaml': 'prettier',
    '.prettierrc.yml': 'prettier',
    '.prettierrc.toml': 'prettier',
    '.prettierignore': 'prettier',
    'prettier.config.js': 'prettier',
    'prettier.config.cjs': 'prettier',
    'prettier.config.mjs': 'prettier',

    // Babel
    '.babelrc': 'babel',
    '.babelrc.js': 'babel',
    '.babelrc.cjs': 'babel',
    '.babelrc.json': 'babel',
    'babel.config.js': 'babel',
    'babel.config.cjs': 'babel',
    'babel.config.json': 'babel',
    'babel.config.ts': 'babel',

    // Vite / Vitest
    'vite.config.js': 'vite',
    'vite.config.mjs': 'vite',
    'vite.config.ts': 'vite',
    'vite.config.cjs': 'vite',
    'vitest.config.js': 'vitest',
    'vitest.config.ts': 'vitest',

    // Webpack
    'webpack.config.js': 'webpack',
    'webpack.config.ts': 'webpack',
    'webpack.config.cjs': 'webpack',
    'webpack.config.mjs': 'webpack',
    'webpack.dev.js': 'webpack',
    'webpack.prod.js': 'webpack',

    // Tailwind
    'tailwind.config.js': 'tailwind',
    'tailwind.config.cjs': 'tailwind',
    'tailwind.config.mjs': 'tailwind',
    'tailwind.config.ts': 'tailwind',

    // Next / Nuxt / Gatsby / Astro / Svelte
    'next.config.js': 'next',
    'next.config.mjs': 'next',
    'next.config.ts': 'next',
    'nuxt.config.js': 'nuxt',
    'nuxt.config.ts': 'nuxt',
    '.nuxtrc': 'nuxt',
    '.nuxtignore': 'nuxt',
    'gatsby-config.js': 'gatsby',
    'gatsby-config.ts': 'gatsby',
    'gatsby-node.js': 'gatsby',
    'astro.config.js': 'astro',
    'astro.config.mjs': 'astro',
    'astro.config.ts': 'astro',
    'svelte.config.js': 'svelte',
    'svelte.config.cjs': 'svelte',
    'docusaurus.config.js': 'docusaurus',
    'docusaurus.config.ts': 'docusaurus',

    // Angular
    'angular.json': 'angular',
    'angular-cli.json': 'angular',
    '.angular-cli.json': 'angular',

    // Go
    'go.mod': 'go-mod',
    'go.sum': 'go-mod',
    'go.work': 'go-mod',
    'go.work.sum': 'go-mod',

    // Python
    'requirements.txt': 'python',
    'pipfile': 'python',
    '.python-version': 'python',
    'manifest.in': 'python',
    'pylintrc': 'python',
    '.pylintrc': 'python',
    'setup.cfg': 'python',
    'pyproject.toml': 'gear',

    // Dart
    '.pubignore': 'dart',

    // Jest
    'jest.config.js': 'jest',
    'jest.config.ts': 'jest',
    'jest.config.json': 'jest',
    'jest.setup.js': 'jest',
    'jest.setup.ts': 'jest',

    // Cypress
    'cypress.json': 'cypress',
    'cypress.config.ts': 'cypress',
    'cypress.config.js': 'cypress',

    // GraphQL
    '.graphqlconfig': 'graphql',
    '.graphqlrc': 'graphql',
    '.graphqlrc.json': 'graphql',
    'graphql.config.json': 'graphql',
    'graphql.config.js': 'graphql',
    'graphql.config.ts': 'graphql',

    // Prisma
    'prisma.yml': 'prisma',

    // Gradle
    'gradle.properties': 'gradle',
    'gradlew': 'gradle',

    // PostCSS
    'postcss.config.js': 'postcss',
    'postcss.config.cjs': 'postcss',
    'postcss.config.ts': 'postcss',
    '.postcssrc': 'postcss',
    '.postcssrc.json': 'postcss',

    // Deno
    'deno.json': 'deno',
    'deno.jsonc': 'deno',

    // Netlify / Vercel
    'netlify.json': 'netlify',
    'netlify.toml': 'netlify',
    'vercel.json': 'vercel',
    '.vercelignore': 'vercel',
    'now.json': 'vercel',

    // Jenkins
    'jenkinsfile': 'jenkins',

    // Nodemon
    'nodemon.json': 'nodemon',

    // SWC
    '.swcrc': 'swc',

    // Biome / Rome
    'biome.json': 'biome',
    'biome.jsonc': 'biome',
    'rome.json': 'rome',

    // Stylelint
    '.stylelintrc': 'stylelint',
    'stylelint.config.js': 'stylelint',
    '.stylelintrc.json': 'stylelint',

    // Editor config
    '.editorconfig': 'editorconfig',

    // CMake
    'cmakelists.txt': 'cmake',
    'cmakecache.txt': 'cmake',

    // NestJS
    'nest-cli.json': 'nest',
    '.nest-cli.json': 'nest',

    // Gulp
    'gulpfile.js': 'gulp',
    'gulpfile.ts': 'gulp',

    // Turbo
    'turbo.json': 'turborepo',

    // Env
    '.direnv': 'gear',
    '.env': 'gear',
    '.env.local': 'gear',
    '.env.development': 'gear',
    '.env.dev': 'gear',
    '.env.production': 'gear',
    '.env.prod': 'gear',
    '.env.test': 'gear',

    // Git hooks (shell)
    'pre-commit': 'shell',
    'commit-msg': 'shell',
    'pre-push': 'shell',
    'post-merge': 'shell',

    // GitLab
    '.gitlab-ci.yml': 'gitlab',

    // Hugo
    '.hugo_build.lock': 'hugo',

    // Text
    'robots.txt': 'text',

    // RSBuild / RSPack / RSLib
    'rsbuild.config.ts': 'rsbuild',
    'rsbuild.config.js': 'rsbuild',
    'rspack.config.js': 'rspack',
    'rspack.config.ts': 'rspack',

    // NX
    'nx.json': 'nx',
    '.nxignore': 'nx',

    // Oxlint
    '.oxlintrc.json': 'oxlint',

    // Drizzle
    'drizzle.config.ts': 'drizzle',

    // Pulumi
    'pulumi.yaml': 'pulumi',

    // Serverless
    'serverless.yml': 'severless',

    // Capacitor / Ionic
    'capacitor.config.json': 'capacitor',
    'capacitor.config.ts': 'capacitor',
    'ionic.config.json': 'ionic',

    // Tauri
    'tauri.conf.json': 'tauri',

    // Cursor / Claude
    '.cursorrules': 'cursor',
    'CLAUDE.md': 'claude',
    '.claude': 'claude',
    '.clauderc': 'claude',
    'claude.json': 'claude',
    'claude.yaml': 'claude',
    'claude.yml': 'claude',
    '.claude.md': 'claude',
    '.claudeignore': 'claude',

    // Shadcn
    'components.json': 'shadcn',

    // Sanity
    'sanity.cli.ts': 'sanity',
    'sanity.config.ts': 'sanity',

    // Dune
    'dune': 'dune',
    'dune-project': 'dune',
    'dune-workspace': 'dune',

    // Bruno
    'bruno.json': 'bruno',

    // Panda
    'panda.config.ts': 'panda',

    // UnoCSS
    'uno.config.js': 'unocss',
    'uno.config.ts': 'unocss',

    // Contentlayer
    'contentlayer.config.ts': 'contentlayer',
    'contentlayer.config.js': 'contentlayer',

    // Knip
    'knip.json': 'knip',
    'knip.ts': 'knip',
    'knip.js': 'knip',

    // Fresh
    'fresh.config.js': 'fresh',
    'fresh.config.ts': 'fresh',

    // Yummacss
    'yumma.css': 'yummacss',
    'yummacss.css': 'yummacss',
  };

  // ══════════════════════════════════════════════════════════════════
  //  Folder name → Icon definition name
  //  (from symbol-icon-theme.json "folderNames")
  // ══════════════════════════════════════════════════════════════════

  static const Map<String, String> _folderNames = {
    // i18n
    'i18n': 'folder-i18n',
    'locales': 'folder-i18n',

    // Auth / Lock
    '.venv': 'folder-lock',
    'auth': 'folder-lock',

    // Core
    'core': 'folder-core',

    // Models
    'models': 'folder-models',

    // Interfaces
    'interface': 'folder-interfaces',
    'interfaces': 'folder-interfaces',

    // Helpers
    'helpers': 'folder-helpers',

    // Shared
    'shared': 'folder-shared',

    // Router
    'router': 'folder-router',
    'routers': 'folder-router',
    'routes': 'folder-router',

    // Modules
    'modules': 'folder-modules',

    // Angular
    'angular': 'folder-angular',
    '.angular': 'folder-angular',

    // Services
    'services': 'folder-services',
    'service': 'folder-services',

    // Providers
    'providers': 'folder-providers',
    'provider': 'folder-providers',

    // Interceptors
    'interceptors': 'folder-interceptors',
    'interceptor': 'folder-interceptors',

    // Pipes
    'pipes': 'folder-pipes',
    'pipe': 'folder-pipes',

    // Firebase / Supabase
    'firebase': 'folder-firebase',
    'supabase': 'folder-supabase',

    // Drizzle
    '.drizzle': 'folder-drizzle',
    'drizzle': 'folder-drizzle',

    // Tina
    'tina': 'folder-tina',

    // Tauri
    'src-tauri': 'folder-tauri',
    'tauri': 'folder-tauri',

    // Cursor / Claude
    '.cursor': 'folder-cursor',
    '.claude-code': 'folder-claude',
    '.claude': 'folder-claude',
    'claude': 'folder-claude',
    'claude-config': 'folder-claude',
    'claude-prompts': 'folder-claude',

    // Vercel
    '.vercel': 'folder-vercel',
    'vercel': 'folder-vercel',

    // Target
    'target': 'folder-target',

    // iOS
    'ios': 'folder-ios',

    // Context
    'context': 'folder-context',
    'contexts': 'folder-context',

    // Middleware
    'middleware': 'folder-middleware',
    'middlewares': 'folder-middleware',

    // Pages / Screens (sky-code)
    'pages': 'folder-sky-code',
    'screens': 'folder-sky-code',

    // Utils
    'util': 'folder-utils',
    'utils': 'folder-utils',
    'utility': 'folder-utils',
    'utilities': 'folder-utils',
    'tools': 'folder-utils',
    'lib': 'folder-utils',

    // Database
    'db': 'folder-database',
    'database': 'folder-database',
    'databases': 'folder-database',

    // Layout
    'layouts': 'folder-layout',
    'layout': 'folder-layout',

    // Docker
    'docker': 'folder-docker',
    'docker-compose': 'folder-docker',
    'dockerfiles': 'folder-docker',
    '.docker': 'folder-docker',

    // Git
    '.git': 'folder-red',

    // GraphQL
    'graphql': 'folder-graphql',
    'gql': 'folder-graphql',

    // App
    'app': 'folder-app',
    'apps': 'folder-app',

    // Config
    'config': 'folder-config',

    // Env
    'env': 'folder-green',

    // Server / Client
    'server': 'folder-orange',
    'client': 'folder-blue',

    // CSS / Styles
    'css': 'folder-purple-code',
    'styles': 'folder-purple-code',

    // Scripts
    'scripts': 'folder-red-code',

    // Storybook
    'storybook': 'folder-pink-outline',
    'stories': 'folder-pink-code',
    '.storybook': 'folder-pink',

    // Types
    'types': 'folder-blue-code',

    // API
    'api': 'folder-red',

    // VS Code
    '.vscode': 'folder-vscode',

    // Frameworks
    '.next': 'folder-gray',
    '.nuxt': 'folder-green',
    '.turbo': 'folder-red',
    '.contentlayer': 'folder-purple',

    // Node modules
    'node_modules': 'folder-node-modules',

    // Cloud
    'aws': 'folder-aws',
    '.azure': 'folder-azure',

    // Nginx
    'nginx': 'folder-nginx',

    // React
    'react': 'folder-react',

    // GitHub / GitLab
    '.github': 'folder-github',
    '.gitlab': 'folder-gitlab',

    // Public / Static / Assets
    'public': 'folder-purple-outline',
    'assets': 'folder-assets',
    'resources': 'folder-assets',
    'static': 'folder-assets',

    // Source
    'source': 'folder-orange-code',
    'src': 'folder-orange-code',

    // Tests
    'test': 'folder-red-code',
    'tests': 'folder-red-code',
    'spec': 'folder-red-code',
    'specs': 'folder-red-code',

    // Docs
    'doc': 'folder-documents',
    'docs': 'folder-documents',
    'documents': 'folder-documents',
    'documentation': 'folder-documents',
    'files': 'folder-documents',

    // Dist / Out
    'dist': 'folder-purple-outline',
    'out': 'folder-purple-outline',

    // Build
    'build': 'folder-build',

    // Components
    'components': 'folder-green-code',

    // Prisma
    'prisma': 'folder-prisma',

    // Android
    'android': 'folder-android',

    // Mail
    'mail': 'folder-mail',
    'mails': 'folder-mail',
    'emails': 'folder-mail',
    'smtp': 'folder-mail',
    'mailers': 'folder-mail',

    // Images
    'image': 'folder-images',
    'images': 'folder-images',

    // Bruno
    '.bru': 'folder-bruno',
    'bru': 'folder-bruno',

    // Mongo
    'mongo': 'folder-mongo',
    'mongodb': 'folder-mongo',

    // Hooks
    'hooks': 'folder-hooks',

    // Constants
    'constants': 'folder-constants',

    // Expo
    'expo': 'folder-expo',
    '.expo': 'folder-expo',

    // Gradle
    'gradle': 'folder-gradle',
    '.gradle': 'folder-gradle',

    // NX
    '.nx': 'folder-gray',

    // Fonts
    'fonts': 'folder-fonts',
    'font': 'folder-fonts',

    // JS
    'js': 'folder-js',
    'javascript': 'folder-js',

    // Sass
    'sass': 'folder-sass',
    'scss': 'folder-sass',

    // macOS / Windows / Linux / Web (generic color folders)
    'macos': 'folder-gray',
    'windows': 'folder-blue',
    'linux': 'folder-orange',
    'web': 'folder-red',

    // UI / Widgets (generic colors)
    'ui': 'folder-green-code',
    'widgets': 'folder-green-code',

    // Redux
    'actions': 'folder-actions',
    'effects': 'folder-effects',
    'reducers': 'folder-reducer',
    'selectors': 'folder-selector',

    // Redis
    'redis': 'folder-redis',
  };
}
