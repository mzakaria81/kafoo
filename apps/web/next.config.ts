import type { NextConfig } from 'next';

const config: NextConfig = {
  // Server-rendered throughout. The whole reason this surface exists rather
  // than the Flutter web build is that a shared kitchen link must preview and
  // index — ADR-0008 measured the alternative at 42 MB on a canvas that can do
  // neither. Nothing here may become a client-only render without revisiting
  // that decision.
  reactStrictMode: true,
};

export default config;
