#!/bin/zsh

###############################################################################
## CONFIGURATION & SETUP
###############################################################################

set -e          # Exit immediately if a command fails
setopt NONOMATCH # Let Zsh ignore bracket expressions in mkdir
setopt NO_HIST_EXPAND

autoload -U colors && colors

step_prompt() {
  echo "${fg[cyan]}➜${reset_color} $1"
  sleep 0.5
}

log_success() {
  echo "${fg[green]}✔ $1${reset_color}"
}

log_error() {
  echo "${fg[red]}✖ $1${reset_color}"
}

log_info() {
  echo "${fg[yellow]}ℹ $1${reset_color}"
}

rollback() {
  log_error "An error occurred. Rolling back changes..."

  # Clean up project directory if it exists
  if [ -d "$PROJECT_NAME" ]; then
    cd "$PROJECT_NAME" || true
    
    # Clean package manager caches and locks based on what's present
    case "$(find . -maxdepth 1 -name '*lock*' -print -quit)" in
      *yarn.lock*)
        echo "Cleaning Yarn cache..."
        yarn cache clean --all
        rm -f yarn.lock
        ;;
      *package-lock.json*)
        echo "Cleaning NPM cache..."
        npm cache clean --force
        rm -f package-lock.json
        ;;
      *pnpm-lock.yaml*)
        echo "Cleaning PNPM store..."
        pnpm store prune
        rm -f pnpm-lock.yaml
        ;;
    esac

    # Remove build artifacts
    rm -rf node_modules .next
    
    # Remove project directory
    cd ..
    rm -rf "$PROJECT_NAME"
    log_success "Deleted project directory '$PROJECT_NAME'."
  fi

  exit 1
}
trap 'rollback' ERR

###############################################################################
## PROJECT VARIABLES
###############################################################################

PROJECT_NAME="deveric-nextjs-15-scafold-app"
AUTHOR_NAME="Eric Gitangu"
AUTHOR_EMAIL="developer.ericgitangu@gmail.com"
AUTHOR_URL="https://developer.ericgitangu.com"
REPO_URL="https://github.com/ericgitangu/$PROJECT_NAME.git"
PKG_MGR="yarn"
# REACT_VERSION="18.2.0"
# REACT_DOM_VERSION="18.2.0"

###############################################################################
## SELECT PACKAGE MANAGER
###############################################################################

log_info "Select a package manager: [yarn / pnpm / npm] (default: yarn)"
read userPkgMgr
if [ -z "$userPkgMgr" ]; then
  PKG_MGR="yarn"
else
  PKG_MGR=$userPkgMgr
fi

case "$PKG_MGR" in
  yarn|Yarn) PKG_MGR="yarn" ;;
  pnpm|Pnpm) PKG_MGR="pnpm" ;;
  npm|Npm)   PKG_MGR="npm" ;;
  *)         log_error "Invalid selection. Defaulting to 'yarn'."; PKG_MGR="yarn" ;;
esac

function run_pm_cmd() {
  local cmd="$1"
  local msg="$2"
  step_prompt "$msg"
  eval "$PKG_MGR $cmd"
}

###############################################################################
## Step 1: CREATE NEXT APP WITH SPECIFIED REACT VERSION
###############################################################################

step_prompt "Step 1: Scaffolding Next.js 15 (App Router) w/ TS, ESLint, Tailwind, Turbopack..."
npx create-next-app@latest "$PROJECT_NAME" \
  --typescript \
  --eslint \
  --tailwind \
  --experimental-app-router \
  --experimental-turbopack \
  --use-$PKG_MGR
log_success "Next.js 15 app scaffolded successfully. Step 1/28 completed."


cd "$PROJECT_NAME"

# Uncomment the desired version - this will spin up the new version of React
# step_prompt "Setting React and React-DOM to version $REACT_VERSION..."

# if [ "$PKG_MGR" = "yarn" ]; then
#   yarn add react@$REACT_VERSION react-dom@$REACT_DOM_VERSION
# elif [ "$PKG_MGR" = "pnpm" ]; then
#   pnpm add react@$REACT_VERSION react-dom@$REACT_DOM_VERSION
# elif [ "$PKG_MGR" = "npm" ]; then
#   npm install react@$REACT_VERSION react-dom@$REACT_DOM_VERSION
# fi

log_success "React and React-DOM set to version $REACT_VERSION. Step 1/28 completed."

###############################################################################
## Step 2: CREATE FOLDER STRUCTURE
###############################################################################

step_prompt "Step 2: Ensuring folder structure..."
mkdir -p \
  app/api/auth/[...nextauth] \
  app/api/trpc \
  app/components \
  app/context \
  app/hooks \
  app/lib \
  app/providers \
  app/server/trpc/router \
  app/theme \
  app/types \
  app/config \
  cypress/e2e \
  tests/unit \
  tests/integration \
  prisma

log_success "Folders created. Step 2/28 completed."

###############################################################################
## Step 3: TRPC PROVIDER
###############################################################################

step_prompt "Step 3: Creating TrpcProvider in app/providers..."
mkdir -p app/providers
cat <<'EOF' > app/providers/TrpcProvider.tsx
'use client';

import React, { useState } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { httpBatchLink } from '@trpc/client';
import superjson from 'superjson';
import { trpc } from '@/hooks/useTRPC';

export function TrpcProvider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());
  const [client] = useState(() =>
    trpc.createClient({
      transformer: superjson,
      links: [
        httpBatchLink({
          url: '/api/trpc',
        }),
      ],
    })
  );

  return (
    <trpc.Provider client={client} queryClient={queryClient}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </trpc.Provider>
  );
}
EOF
log_success "TrpcProvider created. Step 3/28 completed."

###############################################################################
## Step 4: TRPC HOOKS
###############################################################################

step_prompt "Step 4: Creating app/hooks/useTRPC.ts..."
mkdir -p app/hooks
cat <<'EOF' > app/hooks/useTRPC.ts
// app/hooks/useTRPC.ts
import { createTRPCReact } from '@trpc/react-query';
import type { AppRouter } from '@/server/trpc/router';

export const trpc = createTRPCReact<AppRouter>();
EOF
log_success "Created app/hooks/useTRPC.ts. Step 4/28 completed."

###############################################################################
## Step 5: HOOKS: useTheme (Optional)
###############################################################################

step_prompt "Step 5: Creating app/hooks/useTheme.ts..."
cat <<'EOF' > app/hooks/useTheme.ts
import { useContext } from 'react';
import { ThemeContext } from '../context/ThemeContext';

export const useTheme = () => useContext(ThemeContext);

const context = useContext(ThemeContext);
if (!context) {
  throw new Error('useTheme must be used within a ThemeProvider');
}
return context;



EOF
log_success "Created app/hooks/useTheme.ts. Step 5/28 completed."

###############################################################################
## Step 6: INSTALL MAJOR DEPENDENCIES
###############################################################################

step_prompt "Step 6: Installing major dependencies..."
run_pm_cmd "add \
  next-auth@latest next-seo \
  @tanstack/react-query@^4.24 \
  @mui/material @mui/icons-material @emotion/react @emotion/styled \
  @next-auth/prisma-adapter @prisma/client \
  @trpc/client@latest @trpc/next@latest @trpc/react-query@latest @trpc/server@latest \
  axios react-hook-form@^7.54.2 @hookform/resolvers@^3.9.1 superjson zod" \
  "Installing tRPC, React Query, Prisma, MUI, NextAuth, etc."
log_success "Main dependencies installed. Step 6/28 completed."

###############################################################################
## Step 7: INSTALL DEV DEPENDENCIES
###############################################################################

step_prompt "Step 7: Installing dev dependencies..."
run_pm_cmd "add -D \
  prisma \
  typescript \
  @types/node \
  @types/react@$REACT_VERSION \
  @types/react-dom@$REACT_DOM_VERSION \
  eslint-config-prettier \
  prettier \
  tailwindcss \
  postcss \
  autoprefixer \
  eslint-plugin-react \
  eslint-plugin-react-hooks \
  eslint-plugin-jsx-a11y \
  eslint-plugin-import \
  eslint-plugin-next \
  rome" \
  "Installing dev dependencies"
log_success "Dev dependencies installed. Step 7/28 completed."

###############################################################################
## STEP 8: DEDUPE DEPENDENCIES
###############################################################################

step_prompt "Step 8: Deduplicating dependencies to ensure a single React instance..."

if [ "$PKG_MGR" = "yarn" ]; then
    log_info "Installing yarn-deduplicate as a dev dependency..."
    run_pm_cmd "add -D yarn-deduplicate" "Installing yarn-deduplicate..."
    
    log_info "Running yarn-deduplicate via npx..."
    npx yarn-deduplicate
    
    if [ $? -eq 0 ]; then
        log_success "Yarn dependencies deduplicated successfully."
    else
        log_error "yarn-deduplicate failed. Please check the logs for more details."
        exit 1
    fi
elif [ "$PKG_MGR" = "pnpm" ]; then
    # pnpm handles deduplication automatically
    log_info "pnpm automatically deduplicates dependencies."
elif [ "$PKG_MGR" = "npm" ]; then
    run_pm_cmd "dedupe" "Running npm dedupe..."
    
    if [ $? -eq 0 ]; then
        log_success "npm dependencies deduplicated successfully."
    else
        log_error "npm dedupe failed. Please check the logs for more details."
        exit 1
    fi
fi

log_success "Dependency deduplication completed. Step 8/28 completed."

###############################################################################
## STEP 9: PRISMA INIT
###############################################################################

step_prompt "Step 9: Initializing Prisma..."
if [ ! -d "prisma" ]; then
  run_pm_cmd "prisma init" "Initializing Prisma..."
  log_success "Prisma initialized. Step 9/28 completed."
else
  log_success "Prisma already initialized. Skipping step 9/28."
fi

###############################################################################
## STEP 10: TRPC BASE
###############################################################################

step_prompt "Step 10: Creating tRPC base files..."
cat <<'EOF' > app/server/trpc/trpc.ts
import { initTRPC } from '@trpc/server';
import superjson from 'superjson';

const t = initTRPC.create({
  transformer: superjson,
});

export const router = t.router;
export const publicProcedure = t.procedure;
EOF

cat <<'EOF' > app/server/trpc/router/index.ts
import { router, publicProcedure } from '../trpc';
import { z } from 'zod';

export const appRouter = router({
  hello: publicProcedure.query(() => 'Hello tRPC'),
});

export type AppRouter = typeof appRouter;
EOF

mkdir -p app/api/trpc
cat <<'EOF' > app/api/trpc/route.ts
import { createNextApiHandler } from '@trpc/server/adapters/next';
import { appRouter } from '@/server/trpc/router';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  const handler = createNextApiHandler({
    router: appRouter,
    createContext: () => ({}),
  });
  return handler(request);
}

export async function GET(request: Request) {
  const handler = createNextApiHandler({
    router: appRouter,
    createContext: () => ({}),
  });
  return handler(request);
}
EOF
log_success "tRPC structure created. Step 10/28 completed."

###############################################################################
## STEP 11: NEXTAUTH WITH NEXTAUTHHANDLER
###############################################################################

step_prompt "Step 11: Setting up NextAuth with Google using next-auth/next..."
cat <<'EOF' > app/api/auth/[...nextauth]/route.ts
import NextAuth from "next-auth/next";
import { NextAuthHandler } from 'next-auth/next';
import type { NextAuthOptions } from 'next-auth';
import GoogleProvider from 'next-auth/providers/google';

export const runtime = 'nodejs';

// NextAuth config
export const authOptions: NextAuthOptions = {
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_ID || '',
      clientSecret: process.env.GOOGLE_SECRET || '',
    }),
  ],
  session: { strategy: 'jwt' },
  jwt: { secret: process.env.NEXTAUTH_SECRET },
  callbacks: {
    async jwt({ token, account }) {
      if (account) {
        token.accessToken = account.access_token;
      }
      return token;
    },
    async session({ session, token }) {
      session.accessToken = token.accessToken;
      return session;
    },
  },
  secret: process.env.NEXTAUTH_SECRET,
};

const handler = NextAuth(authOptions);
export { handler as GET, handler as POST };
EOF
log_success "NextAuth route fixed using NextAuthHandler() to avoid req.query destruct errors. Step 11/28 completed."

###############################################################################
## STEP 12: MUI THEME
###############################################################################

step_prompt "Step 12: Creating MUI theme (dark mode by default)..."
mkdir -p app/theme
cat <<'EOF' > app/theme/theme.ts
import { createTheme } from '@mui/material/styles';

const theme = createTheme({
  palette: {
    mode: 'dark', // default to dark mode
    primary: { main: '#90caf9' },  // lighter for dark BG
    secondary: { main: '#f48fb1' },
    error: { main: '#f44336' },
    background: {
      default: '#121212',
      paper: '#1e1e1e'
    },
  },
  typography: {
    fontFamily: ['Montserrat', 'sans-serif'].join(','),
    allVariants: {
      color: '#ffffff' // ensure text is visible on dark BG
    }
  },
});

export default theme;
EOF
log_success "MUI theme file created with dark mode & visible text. Step 12/28 completed."

###############################################################################
## STEP 13: NEXT SEO CONFIG
###############################################################################

step_prompt "Step 13: Creating next-seo.config.ts..."
mkdir -p config
cat <<'EOF' > config/next-seo.config.ts
import { DefaultSeoProps } from 'next-seo';

const config: DefaultSeoProps = {
  title: 'deveric-nextjs-15-scafold-app',
  description: 'A Next.js application with TypeScript, tRPC, NextAuth, Prisma, MUI (Dark Mode), and more.',
  openGraph: {
    type: 'website',
    locale: 'en_IE',
    url: 'https://developer.ericgitangu.com',
    site_name: 'deveric-nextjs-15-scafold-app',
    images: [
      {
        url: 'https://developer.ericgitangu.com/_next/image?url=%2Ffavicon.png&w=96&q=75',
        width: 800,
        height: 600,
        alt: 'deveric-nextjs-15-scafold-app',
      },
    ],
  },
};

export default config;
EOF
log_success "next-seo.config.ts created with DefaultSeoProps. Step 13/28 completed."


###############################################################################
## STEP 14: SERVER layout
###############################################################################

step_prompt "Step 14: Replacing layout.tsx with a server layout referencing ClientRoot..."
cat <<'EOF' > app/layout.tsx
'use client';

import { ReactNode } from 'react';
import { CustomThemeProvider } from '@/context/ThemeContext';
import ThemeToggle from '@/components/ThemeToggle';
import { SessionProvider } from 'next-auth/react';
import { TrpcProvider } from '@/providers/TrpcProvider';
import { DefaultSeo } from 'next-seo';
import SEO from '@/config/next-seo.config';

interface RootLayoutProps {
  children: ReactNode;
}

const RootLayout = ({ children }: RootLayoutProps) => {
  return (
    <html lang="en">
      <body>
        <DefaultSeo {...SEO} />
        <SessionProvider>
          <TrpcProvider>
            <CustomThemeProvider>
              <header style={{ display: 'flex', justifyContent: 'flex-end', padding: '1rem' }}>
                <ThemeToggle />
              </header>
              <main>
                {children}
              </main>
            </CustomThemeProvider>
          </TrpcProvider>
        </SessionProvider>
      </body>
    </html>
  );
};

export default RootLayout;

EOF
log_success "server layout.tsx created. Step 14/28 completed."

###############################################################################
## STEP 15: page.tsx
###############################################################################

step_prompt "Step 15: Creating a base page.tsx with acknowledgements..."
cat <<'EOF' > app/page.tsx
'use client';

import { Box, Typography, Button, Link as MuiLink } from '@mui/material';
import { useRouter } from 'next/navigation';
import { GitHub, Language, AutoFixHigh } from '@mui/icons-material';
import ThemeToggle from '@/components/ThemeToggle'; // Import the ThemeToggle component

export default function HomePage() {
  const router = useRouter();

  return (
    <Box sx={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 2,
      textAlign: 'center',
      p: 4,
      color: '#fff',
    }}>
      <Typography variant="h4" gutterBottom>
        Welcome to <strong>deveric-nextjs-15-scafold-app</strong>
      </Typography>
      <Typography variant="body1" sx={{ maxWidth: '480px' }}>
        This project was <strong>automated</strong> using a script by{' '}
        <MuiLink href="https://developer.ericgitangu.com" target="_blank" rel="noopener noreferrer">
          Eric Gitangu
        </MuiLink>.
        <br />
        Check out his GitHub:{' '}
        <MuiLink href="https://github.com/ericgitangu" target="_blank" rel="noopener noreferrer">
          @ericgitangu
        </MuiLink>.
      </Typography>

      <Typography variant="body1">
        The app includes:
      </Typography>
      <ul style={{ textAlign: 'left' }}>
        <li>✅ Next.js 15 + TypeScript + ESLint + Tailwind CSS</li>
        <li>✅ tRPC &amp; React Query integration</li>
        <li>✅ NextAuth (Google OAuth) for authentication</li>
        <li>✅ Prisma (w/ Google Auth fields)</li>
        <li>✅ Material UI (dark mode default)</li>
        <li>✅ Separate server layout & client hooking logic</li>
      </ul>

      <Typography variant="body2">
        Get started by editing <strong>app/page.tsx</strong>. Save and see your changes instantly.
      </Typography>

      <Box sx={{ display: 'flex', gap: 2, mt: 2 }}>
        <Button
          variant="outlined"
          startIcon={<AutoFixHigh />}
          onClick={() => router.push('/api/auth/signin')}
        >
          Auth Test
        </Button>
        <Button
          variant="contained"
          startIcon={<GitHub />}
          href="https://github.com/ericgitangu"
          target="_blank"
        >
          GitHub Repo
        </Button>
        <Button
          variant="contained"
          startIcon={<Language />}
          href="https://nextjs.org/"
          target="_blank"
        >
          Next.js Docs
        </Button>
      </Box>

      <Typography variant="body2" sx={{ mt: 4 }}>
        Script documentation {' '}
        <MuiLink href="https://github.com/ericgitangu/deveric-nextjs-15-scafold-app" target="_blank" rel="noopener noreferrer">
          README
        </MuiLink>{' '}
        {' '}
        |{' '}
        <MuiLink href="https://developer.ericgitangu.com" target="_blank" rel="noopener noreferrer">
          Author
        </MuiLink>
        {' '}
        |{' '}
        <MuiLink href="https://github.com/ericgitangu" target="_blank" rel="noopener noreferrer">
          GitHub
        </MuiLink>
        {' '}
        |{' '}
        <MuiLink href="https://linkedin.com/in/ericgitangu" target="_blank" rel="noopener noreferrer">
          LinkedIn
        </MuiLink>
      </Typography>
    </Box>
  );
}
EOF
log_success "page.tsx created (client) with Material UI, dark mode tips, etc. Step 12/28 completed."

###############################################################################
## STEP 13: PRISMA SCHEMA
###############################################################################

step_prompt "Creating Prisma schema with Google OAuth fields..."
cat <<'EOF' > prisma/schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

model User {
  id            Int       @id @default(autoincrement())
  name          String?
  email         String?   @unique
  emailVerified DateTime?
  image         String?
  accounts      Account[]
  sessions      Session[]
}

model Account {
  id                 Int       @id @default(autoincrement())
  userId             Int
  type               String
  provider           String
  providerAccountId  String
  refresh_token      String?
  access_token       String?
  expires_at         Int?
  token_type         String?
  scope              String?
  id_token           String?
  session_state      String?
  user               User      @relation(fields: [userId], references: [id], onDelete: Cascade)
}

model Session {
  id           Int       @id @default(autoincrement())
  sessionToken String    @unique
  userId       Int
  expires      DateTime
  user         User      @relation(fields: [userId], references: [id], onDelete: Cascade)
}

model VerificationToken {
  identifier String
  token      String    @unique
  expires    DateTime

  @@unique([identifier, token])
}
EOF
log_success "Prisma schema (Google OAuth fields) created. Step 13/28 completed."

###############################################################################
## STEP 14: lib/prisma.ts
###############################################################################

step_prompt "Creating app/lib/prisma.ts..."
mkdir -p app/lib
cat <<'EOF' > app/lib/prisma.ts
import { PrismaClient } from '@prisma/client';

declare global {
  // allow global var declarations
  // eslint-disable-next-line no-var
  var prisma: PrismaClient | undefined;
}

export const prisma =
  global.prisma ||
  new PrismaClient({
    log: ['query'],
  });

if (process.env.NODE_ENV !== 'production') global.prisma = prisma;
EOF
log_success "lib/prisma.ts created. Step 14/28 completed."

###############################################################################
## STEP 15: PRISMA GENERATE
###############################################################################

step_prompt "Generating Prisma client..."
run_pm_cmd "prisma generate" "Generating Prisma client..."
log_success "Prisma client generated. Step 15/28 completed."

###############################################################################
## STEP 16: NEXTAUTH TYPE DEFINITIONS
###############################################################################

step_prompt "Step 16: Creating NextAuth types..."
mkdir -p app/types
cat <<'EOF' > app/types/auth.d.ts
import NextAuth from 'next-auth';

declare module 'next-auth' {
  interface Session {
    accessToken?: string;
  }
}
EOF
log_success "auth.d.ts for NextAuth created. Step 16/28 completed."

###############################################################################
## STEP 17: THEME CONTEXT & THEME TOGGLE (Dark Mode)
###############################################################################

step_prompt "Step 17: Creating ThemeContext & ThemeToggle with default dark mode..."
mkdir -p app/context
cat <<'EOF' > app/context/ThemeContext.tsx
'use client';

import React, { createContext, useState, useEffect, ReactNode } from 'react';
import { ThemeProvider as MuiThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';

interface ThemeContextType {
  toggleColorMode: () => void;
}

export const ThemeContext = createContext<ThemeContextType>({
  toggleColorMode: () => {},
});

export function CustomThemeProvider({ children }: { children: ReactNode }) {
  const [mode, setMode] = useState<'light' | 'dark'>('dark');

  useEffect(() => {
    // Attempt to detect user preference
    const userPrefDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    setMode(userPrefDark ? 'dark' : 'dark'); // force default dark
  }, []);

  const toggleColorMode = () => {
    setMode((prev) => (prev === 'light' ? 'dark' : 'light'));
  };

  const theme = React.useMemo(() =>
    createTheme({
      palette: {
        mode,
        primary: { main: '#90caf9' },
        secondary: { main: '#f48fb1' },
        background: {
          default: mode === 'dark' ? '#121212' : '#f5f5f5',
          paper: mode === 'dark' ? '#1e1e1e' : '#ffffff'
        },
      },
      typography: {
        fontFamily: 'Montserrat, sans-serif',
        allVariants: { color: mode === 'dark' ? '#fff' : '#000' }
      }
    }), [mode]);

  return (
    <ThemeContext.Provider value={{ toggleColorMode }}>
      <MuiThemeProvider theme={theme}>
        <CssBaseline />
        {children}
      </MuiThemeProvider>
    </ThemeContext.Provider>
  );
}
EOF

mkdir -p app/components
cat <<'EOF' > app/components/ThemeToggle.tsx
'use client';

import React, { useContext, useState, useEffect } from 'react';
import { IconButton } from '@mui/material';
import { Brightness4, Brightness7 } from '@mui/icons-material';
import { ThemeContext } from '@/context/ThemeContext';

const ThemeToggle = () => {
  const { toggleColorMode } = useContext(ThemeContext);
  const [mode, setMode] = useState<'light' | 'dark'>('dark');

  useEffect(() => {
    const userPreference = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    setMode(userPreference);
  }, []);

  const handleToggle = () => {
    toggleColorMode();
    setMode((prev) => (prev === 'light' ? 'dark' : 'light'));
  };

  return (
    <IconButton onClick={handleToggle} color="inherit">
      {mode === 'dark' ? <Brightness7 /> : <Brightness4 />}
    </IconButton>
  );
};

export default ThemeToggle;
EOF
log_success "Theme context & ThemeToggle created with forced dark mode. Step 17/28 completed."

###############################################################################
## STEP 18: Setup next-seo.config.ts
###############################################################################

step_prompt "Step 18: Creating next-seo.config.ts..."
cat <<'EOF' > app/config/next-seo.config.ts
import { DefaultSeoProps } from 'next-seo';

const config: DefaultSeoProps = {
  title: 'deveric-nextjs-15-scafold-app',
  description: 'A Next.js 15 (App Router) project with TypeScript, dark-mode Material UI, tRPC, NextAuth, and Prisma.',
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://deveric-nextjs-15-scafold-app.vercel.app',
    siteName: 'deveric-nextjs-15-scafold-app',
    images: [
      {
        url: 'https://deveric-nextjs-15-scafold-app.vercel.app/og-image.png',
        width: 1200,
        height: 630,
        alt: 'deveric-nextjs-15-scafold-app',
      },
    ],
  },
  additionalMetaTags: [
    {
      name: 'viewport',
      content: 'width=device-width, initial-scale=1'
    },
    {
      name: 'description',
      content: "Deveric's scafold Next.js application with TypeScript, tRPC, NextAuth, Prisma, MUI (Dark Mode), and more."
    },
    {
      name: 'keywords',
      content: 'Next.js, TypeScript, tRPC, NextAuth, Prisma, MUI, Dark Mode, Next.js 15, Next.js 15 Scafold, Next.js 15 Scafold App, Next.js 15 Scafold App by Eric Gitangu'
    },
    {
      name: 'author',
      content: 'Eric Gitangu'
    },
    {
      name: 'robots',
      content: 'index, follow'
    },
    {
      name: 'googlebot',
      content: 'index, follow'
    },
    {
      name: 'google-site-verification',
      content: 'YOUR_GOOGLE_SITE_VERIFICATION_CODE'
    },
    {
      name: 'msvalidate.01',
      content: 'YOUR_BING_VERIFICATION_CODE'
    },
    {
      name: 'yandex-verification',
      content: 'YOUR_YANDEX_VERIFICATION_CODE'
    },
    {
      name: 'alexaVerifyID',
      content: 'YOUR_ALEXA_VERIFY_ID'
    }
  ]
};

export default config;
EOF
log_success "next-seo.config.ts created. Step 18/28 completed."

###############################################################################
## STEP 19: Setup test frameworks
###############################################################################

step_prompt "Step 19: Installing test frameworks..."
run_pm_cmd "add -D jest @types/jest ts-jest @testing-library/react @testing-library/jest-dom mocha @types/mocha ts-node cypress" \
  "Installing Jest, Mocha, Cypress..."
log_success "Jest, Mocha, Cypress installed. Step 19/28 completed."

step_prompt "Step 20: Creating test configs..."
cat <<'EOF' > jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'jsdom',
  testPathIgnorePatterns: ['/node_modules/', '/.next/'],
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
};
EOF

cat <<'EOF' > jest.setup.js
import '@testing-library/jest-dom';
EOF

cat <<'EOF' > mocha.config.js
module.exports = {
  require: 'ts-node/register',
  spec: 'tests/integration/**/*.test.ts',
  timeout: 10000,
};
EOF

cat <<'EOF' > mocha.opts
--require ts-node/register
--recursive
--timeout 10000
EOF

mkdir -p cypress/e2e
cat <<'EOF' > cypress/e2e/example.cy.ts
describe('Example E2E Test', () => {
  it('Visits the app root url', () => {
    cy.visit('/');
    cy.contains('h1', 'Welcome to Next.js!');
  });
});
EOF
log_success "Jest, Mocha, Cypress configs & example tests created. Step 20/28 completed."

###############################################################################
## STEP 21: ADD UNIT & INTEGRATION EXAMPLES
###############################################################################

step_prompt "Step 21: Adding sample unit & integration tests..."
mkdir -p tests/unit tests/integration

cat <<'EOF' > tests/unit/example.test.ts
import { trpc } from '@/hooks/useTRPC';

describe('Example Unit Test', () => {
  it('should return Hello tRPC', async () => {
    // Might require mocking or a real server for real test
    const result = await trpc.hello.query();
    expect(result).toBe('Hello tRPC');
  });
});
EOF

cat <<'EOF' > tests/integration/example.test.ts
import { expect } from 'chai';
import { appRouter } from '@/server/trpc/router';

describe('Example Integration Test', () => {
  it('should return Hello tRPC from router', async () => {
    const response = await appRouter.createCaller({}).hello();
    expect(response).to.equal('Hello tRPC');
  });
});
EOF

log_success "Unit & integration test samples created. Step 21/28 completed."

###############################################################################
## STEP 22: CREATE .GITIGNORE
###############################################################################

step_prompt "Step 22: Creating .gitignore..."
cat <<'EOF' > .gitignore
node_modules/
.env
.DS_Store
.next/
prisma/.env
coverage/
cypress/videos/
cypress/screenshots/
EOF
log_success ".gitignore created. Step 22/28 completed."

###############################################################################
## STEP 23: CREATE LICENSE
###############################################################################

step_prompt "Step 23: Creating MIT license..."
cat <<EOF > LICENSE
MIT License

Copyright (c)
$(date +"%Y") $AUTHOR_NAME

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

EOF
log_success "MIT License created. Step 23/28 completed."

###############################################################################
## STEP 24: CREATE README
###############################################################################

# Define variables
PROJECT_NAME="deveric-nextjs-15-scafold-app"
REPO_URL="https://github.com/EricGitangu/deveric-nextjs-15-scafold-app.git"
PKG_MGR="yarn" # or npm, pnpm
AUTHOR_NAME="Eric Gitangu"
AUTHOR_EMAIL="developer@ericgitangu.com"
AUTHOR_URL="https://developer.ericgitangu.com"

# Inform about the step
echo "Step 24: Creating README..."

# Generate README.md using echo with escaped backticks and variable interpolation
echo -e "# 🦄 ${PROJECT_NAME}\n\n\
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)\n\
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#contributing)\n\
[![Jest](https://img.shields.io/badge/Test-Jest-blue.svg)](#testing)\n\
[![Mocha](https://img.shields.io/badge/Test-Mocha-red.svg)](#testing)\n\
[![Cypress](https://img.shields.io/badge/Test-Cypress-orange.svg)](#testing)\n\n\
![Next.js Logo](https://nextjs.org/static/favicon/favicon-16x16.png)\n\n\
## 📚 Table of Contents\n\n\
- [✨ Scaffolding Instructions](#-scaffolding-instructions)\n\
- [📝 Description](#-description)\n\
- [🔧 Installation](#-installation)\n\
- [🚀 Usage](#-usage)\n\
- [🧪 Testing](#-testing)\n\
  - [Unit Tests (Jest)](#unit-tests-jest)\n\
  - [Integration Tests (Mocha)](#integration-tests-mocha)\n\
  - [End-to-End Tests (Cypress)](#end-to-end-tests-cypress)\n\
- [🎉 Features](#-features)\n\
- [🧰 Additional Resources](#-additional-resources)\n\
- [🤝 Contributing](#-contributing)\n\
- [📄 License](#-license)\n\
- [📬 Contact](#-contact)\n\
- [🏗️ Project Structure](#-project-structure)\n\
- [📈 Deployment](#-deployment)\n\
- [🧩 Integrations](#-integrations)\n\
- [🛡️ Security](#-security)\n\
- [📦 Packaging](#-packaging)\n\
- [🧹 Maintenance](#-maintenance)\n\
- [📚 References](#-references)\n\
- [👨‍💻 Maintainer](#-maintainer)\n\n\
## ✨ Scaffolding Instructions\n\n\
Welcome to the **${PROJECT_NAME}**! This project was automatically generated using our custom scaffolding script, designed to streamline the setup process for a robust Next.js application integrated with modern technologies. Below are the detailed steps and capabilities of the script:\n\n\
### 🛠️ Prerequisites\n\n\
Before running the scaffolding script, ensure you have the following installed on your system:\n\n\
- **Node.js** (v18.x or later)\n\
- **Yarn** (v1.22.22) or **npm** (v7.x or later) or **pnpm** (v6.x or later)\n\
- **Git**\n\
- **jq** (for JSON processing)\n\n\
### 📜 Running the Scaffolding Script\n\n\
1. **Clone the Repository:**\n\n\
   \`\`\`bash\n\
   git clone ${REPO_URL}\n\
   \`\`\`\n\n\
2. **Navigate to the Project Directory:**\n\n\
   \`\`\`bash\n\
   cd ${PROJECT_NAME}\n\
   \`\`\`\n\n\
3. **Make the Script Executable:**\n\n\
   If the script isn't already executable, grant execute permissions:\n\n\
   \`\`\`bash\n\
   chmod +x next-app.sh\n\
   \`\`\`\n\n\
4. **Run the Setup Script:**\n\n\
   \`\`\`bash\n\
   ./next-app.sh\n\
   \`\`\`\n\n\
   **What the Script Does:**\n\n\
   - **Scaffolds a Next.js 15 Application:** Initializes a Next.js project with the App Router using a specific version of \\\`create-next-app\\\` to ensure compatibility.\n\
   - **Configures React 19:** Implicitly installs React and React-DOM at version 19 to maintain consistency and avoid multiple React instances using the npx create-next-app command.\n\
   - **Installs Major Dependencies:** Adds essential packages such as tRPC, React Query, Prisma, Material UI (with dark mode), NextAuth, and more, ensuring they are compatible with React 19.\n\
   - **Sets Up Development Tools:** Installs development dependencies including TypeScript, ESLint, Prettier, Tailwind CSS, and others for a seamless development experience.\n\
   - **Enforces Single React Version:** Utilizes package manager-specific configurations (\\\`resolutions\\\` for Yarn, \\\`overrides\\\` for pnpm/npm) to ensure only one instance of React is used across all dependencies.\n\
   - **Deduplicates Dependencies:** Runs deduplication processes to eliminate redundant packages, preventing potential conflicts.\n\
   - **Creates Project Structure:** Sets up necessary folders, hooks, providers, and configuration files.\n\
   - **Generates a Comprehensive README:** Automatically creates a detailed \\\`README.md\\\` capturing all aspects of the project setup.\n\
   - **Creates CONTRIBUTING.md & CODE_OF_CONDUCT.md:** Automatically creates detailed \\\`CONTRIBUTING.md\\\` & \\\`CODE_OF_CONDUCT.md\\\` files.\n\
   - **Creates .gitignore:** Automatically creates a detailed \\\`.gitignore\\\` file.\n\
   - **Creates LICENSE:** Automatically creates a detailed \\\`LICENSE\\\` file.\n\
   - **Creates tsconfig.json:** Automatically creates a detailed \\\`tsconfig.json\\\` file.\n\
   - **Creates next-seo.config.ts:** Automatically creates a detailed \\\`next-seo.config.ts\\\` file with aliases configured.\n\
   - **Creates jest.config.js:** Automatically creates a detailed \\\`jest.config.js\\\` file.\n\
   - **Creates jest.setup.js:** Automatically creates a detailed \\\`jest.setup.js\\\` file.\n\
   - **Creates mocha.config.js:** Automatically creates a detailed \\\`mocha.config.js\\\` file.\n\
   - **Creates mocha.opts:** Automatically creates a detailed \\\`mocha.opts\\\` file.\n\
   - **Creates cypress/e2e/example.cy.ts:** Automatically creates a detailed \\\`cypress/e2e/example.cy.ts\\\` file.\n\
   - **Creates tests/unit/example.test.ts:** Automatically creates a detailed \\\`tests/unit/example.test.ts\\\` file.\n\
   - **Creates tests/integration/example.test.ts:** Automatically creates a detailed \\\`tests/integration/example.test.ts\\\` file.\n\
   - **Creates pages.tsx and layout.tsx:** Automatically creates detailed \\\`pages.tsx\\\` & \\\`layout.tsx\\\` files with the relevant providers session, auth, trpc, theme, etc.\n\
   - **Creates globals.css:** Automatically creates a detailed \\\`globals.css\\\` file.\n\
   - **Creates prisma/schema.prisma:** Automatically creates a detailed \\\`prisma/schema.prisma\\\` file.\n\
   - **Creates public/og-image.png:** Automatically creates a detailed \\\`public/og-image.png\\\` file.\n\
   - **Creates scripts/setup.sh:** Automatically creates a detailed \\\`scripts/setup.sh\\\` file.\n\
   - **Creates package.json:** Automatically creates a detailed \\\`package.json\\\` file.\n\
   - **Creates README.md:** Automatically creates a detailed \\\`README.md\\\` file.\n\
   - **Creates components, context, hooks, providers, utils, etc:** Automatically creates detailed \\\`components, context, hooks, providers, utils, etc.\\\` files with some pre-configured examples.\n\n\
### ⚙️ Customizing the Script\n\n\
The scaffolding script is designed to be flexible. You can adjust variables such as:\n\n\
- **\`PROJECT_NAME\`**: Change the default project name.\n\
- **\`PKG_MGR\`**: Switch between \\\`yarn\\\`, \\\`npm\\\`, or \\\`pnpm\\\` based on your preference.\n\
- **\`AUTHOR_NAME\`**, **\`AUTHOR_EMAIL\`**, **\`AUTHOR_URL\`**: Update contact information in the README.\n\n\
Feel free to modify the script (\\\`setup.sh\\\`) to suit your project's specific needs.\n\n\
---\n\n\
## 📝 Description\n\n\
A **Next.js 15 (App Router)** project with **TypeScript**, **dark-mode** **Material UI**, **tRPC**, **NextAuth**, and **Prisma**. This application is designed to provide a scalable and maintainable foundation for modern web development, leveraging powerful tools and best practices.\n\n\
---\n\n\
## 🔧 Installation\n\n\
Clone the repository and install the dependencies using your preferred package manager.\n\n\
\`\`\`bash\n\
git clone ${REPO_URL}\n\
cd ${PROJECT_NAME}\n\
${PKG_MGR} install\n\
\`\`\`\n\n\
> **Note:** Replace \\\`${PKG_MGR} install\\\` with \\\`npm install\\\` or \\\`pnpm install\\\` if you're using a different package manager.\n\n\
---\n\n\
## 🚀 Usage\n\n\
Start the development server and navigate to [http://localhost:3000](http://localhost:3000) to view the application.\n\n\
\`\`\`bash\n\
${PKG_MGR} dev\n\
\`\`\`\n\n\
> **Note:** Replace \\\`${PKG_MGR} dev\\\` with \\\`npm run dev\\\` or \\\`pnpm dev\\\` based on your package manager.\n\n\
---\n\n\
## 🧪 Testing\n\n\
This project includes a comprehensive testing setup covering unit, integration, and end-to-end tests.\n\n\
### Unit Tests (Jest)\n\n\
Run unit tests to ensure individual components and functions work as expected.\n\n\
\`\`\`bash\n\
${PKG_MGR} test\n\
\`\`\`\n\n\
### Integration Tests (Mocha)\n\n\
Execute integration tests to validate the interactions between different parts of the application.\n\n\
\`\`\`bash\n\
${PKG_MGR} test:integration\n\
\`\`\`\n\n\
### End-to-End Tests (Cypress)\n\n\
Launch Cypress to perform end-to-end testing, simulating real user interactions.\n\n\
\`\`\`bash\n\
${PKG_MGR} cypress:open\n\
\`\`\`\n\n\
> **Note:** Ensure the development server is running before executing end-to-end tests.\n\n\
---\n\n\
## 🎉 Features\n\n\
- **Next.js 15 (App Router):** Leverage the latest features of Next.js for building scalable applications.\n\
- **TypeScript:** Enjoy type safety and enhanced developer experience with TypeScript integration.\n\
- **Material UI with Dark Mode:** Implement sleek and responsive UI components with built-in dark mode support.\n\
- **tRPC:** Build end-to-end type-safe APIs effortlessly.\n\
- **NextAuth:** Secure and flexible authentication solutions.\n\
- **Prisma:** Robust database ORM for seamless data management.\n\
- **Tailwind CSS:** Utility-first CSS framework for rapid UI development.\n\
- **ESLint & Prettier:** Maintain code quality and consistency with automated linting and formatting.\n\
- **Turbopack:** Utilize the high-performance bundler for optimized builds.\n\
- **Comprehensive Testing:** Ensure application reliability with Jest, Mocha, and Cypress integrations.\n\n\
---\n\n\
## 🧰 Additional Resources\n\n\
- **[Next.js Documentation](https://nextjs.org/docs)**\n\
- **[Material UI Documentation](https://mui.com/getting-started/installation/)**\n\
- **[tRPC Documentation](https://trpc.io/docs)**\n\
- **[Prisma Documentation](https://www.prisma.io/docs/)**\n\
- **[NextAuth.js Documentation](https://next-auth.js.org/getting-started/introduction)**\n\
- **[Tailwind CSS Documentation](https://tailwindcss.com/docs)**\n\
- **[Jest Documentation](https://jestjs.io/docs/getting-started)**\n\
- **[Mocha Documentation](https://mochajs.org/#getting-started)**\n\
- **[Cypress Documentation](https://docs.cypress.io/guides/overview/why-cypress)**\n\
- **[Turbopack Documentation](https://turbopack.dev/docs/introduction)**\n\
- **[Yarn Resolutions](https://classic.yarnpkg.com/en/docs/selective-version-resolutions/)**\n\
- **[pnpm Overrides](https://pnpm.io/cli/package-overrides)**\n\
- **[npm Overrides](https://docs.npmjs.com/cli/v8/configuring-npm/package-json#overrides)**\n\n\
---\n\n\
## 🤝 Contributing\n\n\
Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.\n\n\
---\n\n\
## 📄 License\n\n\
This project is licensed under the [MIT License](LICENSE).\n\n\
---\n\n\
## 📬 Contact\n\n\
**Author:** ${AUTHOR_NAME}  \n\
**Email:** [${AUTHOR_EMAIL}](mailto:${AUTHOR_EMAIL})  \n\
**Website:** [https://${AUTHOR_URL}](https://${AUTHOR_URL})  \n\
**GitHub:** [EricGitangu](https://github.com/EricGitangu)\n\n\
---\n\n\
## 🧪 Testing Instructions\n\n\
Ensure all tests pass to maintain code integrity and reliability.\n\n\
### Running All Tests\n\n\
\`\`\`bash\n\
${PKG_MGR} test\n\
\`\`\`\n\n\
### Running Unit Tests Only\n\n\
\`\`\`bash\n\
${PKG_MGR} test:unit\n\
\`\`\`\n\n\
### Running Integration Tests Only\n\n\
\`\`\`bash\n\
${PKG_MGR} test:integration\n\
\`\`\`\n\n\
### Running End-to-End Tests Only\n\n\
\`\`\`bash\n\
${PKG_MGR} cypress:open\n\
\`\`\`\n\n\
---\n\n\
## 🏗️ Project Structure\n\n\
\`\`\`\n\
${PROJECT_NAME}/\n\
├── app/\n\
│   ├── components/\n\
│   │   └── SEO.tsx\n\
│   ├── hooks/\n\
│   │   ├── useTRPC.ts\n\
│   │   └── useTheme.ts\n\
│   ├── providers/\n\
│   │   └── TrpcProvider.tsx\n\
│   ├── layout.tsx\n\
│   ├── page.tsx\n\
│   └── globals.css\n\
├── prisma/\n\
│   └── schema.prisma\n\
├── public/\n\
│   └── og-image.png\n\
├── scripts/\n\
│   └── setup.sh\n\
├── .eslintrc.js\n\
├── .prettierrc\n\
├── next.config.js\n\
├── tailwind.config.js\n\
├── tsconfig.json\n\
├── package.json\n\
├── README.md\n\
└── LICENSE\n\
\`\`\`\n\n\
> **Note:** This structure may vary based on your project's specific needs.\n\n\
---\n\n\
## 📈 Deployment\n\n\
1. **Push to GitHub:**
   > **Note:** This script does the initial commit. Create your repo first, e.g, github.com/{AUTHOR_NAME}/{PROJECT_NAME}. Ensure SSH key is added to GitHub and locally ~/.ssh/id_rsa.pub for pull/push access.
   \`\`\`bash
   git remote add origin https://github.com/${AUTHOR_NAME}/${PROJECT_NAME}.git
   git branch -M main
   git push -u origin main
   \`\`\`\n\n\
2. **Connect to Vercel:**\n\n\
   - Visit [Vercel](https://vercel.com/) and sign in.\n\
   - Import your GitHub repository.\n\
   - Follow the prompts to deploy.\n\n\
> **Tip:** Ensure environment variables and secrets are correctly configured in your deployment platform.\n\n\
---\n\n\
## 🧩 Integrations\n\n\
- **tRPC:** For building type-safe APIs without the need for a schema or code generation.\n\
- **Prisma:** Simplifies database management with an intuitive ORM.\n\
- **NextAuth:** Provides authentication solutions with support for multiple providers.\n\
- **Material UI:** Offers a comprehensive suite of UI components with theming capabilities.\n\
- **Tailwind CSS:** Enables rapid UI development with utility-first CSS.\n\
- **ESLint & Prettier:** Ensures code quality and consistency across the codebase.\n\
- **Turbopack:** Enhances build performance with an advanced bundler.\n\n\
---\n\n\
## 🛡️ Security\n\n\
- **Dependencies:** Regularly update dependencies to patch known vulnerabilities.\n\
- **Environment Variables:** Securely manage sensitive information using environment variables.\n\
- **Authentication:** Utilize robust authentication mechanisms provided by NextAuth.\n\
- **Dependabot:** Consider using Dependabot to automatically monitor your dependencies.\n\
- **GitHub Actions:** Consider using GitHub Actions for CI/CD and security monitoring.\n\n\
---\n\n\
## 📦 Packaging\n\n\
- **Build Scripts:** Customize build processes in \`package.json\` as needed.\n\
- **Optimizations:** Leverage Next.js and Turbopack optimizations for production-ready builds.\n\n\
---\n\n\
## 🧹 Maintenance\n\n\
- **Regular Updates:** Keep dependencies and tools up-to-date.\n\
- **Code Reviews:** Implement a code review process to maintain code quality.\n\
- **Documentation:** Continuously update documentation to reflect changes.\n\n\
---\n\n\
## 📚 References\n\n\
> **Note**: Tested with React 19, React-DOM 19 & Next.js 15.\n\n\
- **[Next.js 15 Documentation](https://nextjs.org/docs/app)**\n\
- **[React 19 Documentation](https://react.dev/reference/react)**\n\
- **[React-DOM 19 Documentation](https://react.dev/reference/react-dom)**\n\
- **[Material UI Documentation](https://mui.com/getting-started/installation/)**\n\
- **[tRPC Documentation](https://trpc.io/docs)**\n\
- **[Prisma Documentation](https://www.prisma.io/docs/)**\n\
- **[NextAuth.js Documentation](https://next-auth.js.org/getting-started/introduction)**\n\n\
---\n\n\
## 👨‍💻 Maintainer\n\n\
- 👤 **Name:** Eric Gitangu\n\
- 📧 **Email:** [developer@ericgitangu.com](mailto:developer@ericgitangu.com)\n\
- 🌐 **Website:** [https://developer.ericgitangu.com](https://developer.ericgitangu.com)\n\
- 🐙 **GitHub:** [EricGitangu](https://github.com/EricGitangu)\n\
- 💼 **LinkedIn:** [linkedin.com/in/ericgitangu](https://linkedin.com/in/ericgitangu)\n\n\
---" > README.md

log_success "README created. Step 24/28 completed."

###############################################################################
## STEP 25: CONTRIBUTING & CODE OF CONDUCT
###############################################################################

step_prompt "Step 25: Creating CONTRIBUTING.md & CODE_OF_CONDUCT.md..."

cat <<'EOF' > CONTRIBUTING.md
# Contributing

## How to Contribute

1. Fork & clone
2. Create a branch
3. Commit changes
4. Create Pull Request
EOF

cat <<'EOF' > CODE_OF_CONDUCT.md
# Code of Conduct

We pledge to make participation in our community a harassment-free experience.

Instances of abusive behavior may be reported to maintainers.
EOF

log_success "CONTRIBUTING.md & CODE_OF_CONDUCT.md created. Step 25/28 completed."

###############################################################################
## STEP 26: TSCONFIG ALIASES
###############################################################################

step_prompt "Step 26: Updating tsconfig.json with multiple aliases..."
cat <<'EOF' > tsconfig.json
{
  "compilerOptions": {
    "target": "ES2021",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./app/*"],
      "@components/*": ["./app/components/*"],
      "@hooks/*": ["./app/hooks/*"],
      "@context/*": ["./app/context/*"],
      "@types/*": ["./app/types/*"],
      "@themes/*": ["./app/theme/*"],
      "@lib/*": ["./app/lib/*"],
      "@server/*": ["./app/server/*"],
      "@providers/*": ["./app/providers/*"],
      "@config/*": ["./app/config/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF
log_success "tsconfig.json updated with path aliases. Step 26/28 completed."

###############################################################################
## STEP 27: GIT INIT & COMMIT
###############################################################################

step_prompt "Step 27: Initializing Git repository..."
git init
git add .
git commit -m "Initial commit: Next.js 15 + Dark MUI + tRPC + NextAuth + Prisma"
git branch -M main
log_success "Repo initialized & initial commit done. Step 27/28 completed."

###############################################################################
## COMPLETION MESSAGE
###############################################################################

step_prompt "Step 28: Setup complete 🦄"
echo ""
log_success "Setup complete 🦄. Step 28/28 completed 💯."
log_info "1. Optionally create a GitHub repo: https://github.com/new"
log_info "2. git remote add origin $REPO_URL && git push -u origin main"
log_info "3. $PKG_MGR dev"
echo ""

echo "Tips 🚀"
echo "• Add env vars in .env.local (NEXTAUTH_SECRET, DATABASE_URL, GOOGLE_ID, etc.)"
echo "• Hooks are only in ClientRoot & 'use client' files"
echo "• NextAuthHandler used for NextAuth route => no more destruct errors"
echo "• Layout is server component, hooking logic in ClientRoot"
echo "Enjoy your Next.js 15 dark theme app!"
