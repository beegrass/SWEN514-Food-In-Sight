// import './LandingPage.css';

const LandingPage= () => {
    // console.log("landing page rendered called!")
    return (
        <div className="landing-container">
            <header className="header">
                <h1>Welcome to Food-in-Sight</h1>
                <p>Your go-to app for food and ingredient insights.</p>
            </header>
            <main className="main-content">
                <section className="upload-section">
                    <h2>Upload Food Images</h2>
                    <input type="file" accept="image/*"/>
                    <button className="upload-button">Upload</button>
                </section>
                <section className="search-section">
                    <h2>Search Ingredients</h2>
                    <input type="text" placeholder="Search for ingredients..."/>
                    <button className="search-button">Search</button>
                </section>
                <section>
                    <h2>Translate A Label</h2>
                    <input type="file" accept="image/*"/>
                    <button className="translate-label">Translate text in image</button>
                </section>
            </main>
        </div>
    );
};

export default LandingPage;