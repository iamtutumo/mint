/** @type {import('next').NextConfig} */
const nextConfig = {
  basePath: '/voice',
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
  },
 
  eslint: {
    ignoreDuringBuilds: true,
  },
}

export default nextConfig
