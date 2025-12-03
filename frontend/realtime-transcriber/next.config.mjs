/** @type {import('next').NextConfig} */
const nextConfig = {
  basePath: '/transcribe',
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
  },
 
}

export default nextConfig
