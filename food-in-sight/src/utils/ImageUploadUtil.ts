/**
 * This is a method which takes in an image file and a Pre-Signed URL provided by the API Gateway and uploads the image
 * to the destination S3 Bucket
 * @param imageFile The image to upload to the S3 Bucket
 * @param presignedUrl The S3 Pre-Signed URl to upload the image to
 */
export const imageUpload = async (imageFile: any, presignedUrl: URL) => {
    try {
        const response = await fetch(presignedUrl, {
            method: 'PUT',
            body: imageFile,
            headers: {
                'Content-Type': `${imageFile.type}`, //Needed to manually set this to match the content type when creating the presigned url
            },
        });

        if (response.ok) {
            console.log('Upload successful!');
            return response;
        } else {
            console.error('Upload failed:', response.json());
            return false;
        }
    } catch (error) {
        console.error('Error uploading image:', error);
        return false;
    }
};

/**
 * This is a method which sends a request for a Pre-Signed URL for an S3 Bucket
 * @param endpoint The endpoint which will be appended to the base API URI
 * @param filename The name of the file you will be uploading using the signed url
 */
export const getPresignedUrl =  async (endpoint: string, filename: string, contentType: string = '') => {
    const baseURI = import.meta.env.VITE_API_GATEWAY_URL
    const uri = baseURI + endpoint;
    console.log(`uri: ${uri}`)
    try {
        const response = await fetch(uri, {
            method: 'post',
            body: contentType !== '' ? JSON.stringify({
                "fileName": filename,
                "contentType": contentType
            }) : JSON.stringify({
                "fileName": filename,
            }),
            headers: {
                'Content-Type': 'application/json',
            },
        });

        const data = await response.json(); // Assuming the URL is returned in a JSON object
        console.log("presigned from the func: ", data['url']);
        console.log('image_s3_url: ', data['image_url']);
        return data;
    } catch (error) {
        console.error('Error getting pre-signed URL:', error);
    }
}

/**
 * This function generates the current date in the aws x-amz-date format needed to verify that the signed url is unexpired
 */
// function generateAmzDate() {
//     const now = new Date();
//
//     const year = now.getUTCFullYear();
//     const month = String(now.getUTCMonth() + 1).padStart(2, '0');
//     const day = String(now.getUTCDate()).padStart(2, '0');
//     const hours = String(now.getUTCHours()).padStart(2, '0');
//     const minutes = String(now.getUTCMinutes()).padStart(2, '0');
//     const seconds = String(now.getUTCSeconds()).padStart(2, '0');
//
//     return `${year}${month}${day}T${hours}${minutes}${seconds}Z`;
// }