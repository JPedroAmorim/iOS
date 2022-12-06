import XCTest
import MEGADomainMock
import MEGADomain
@testable import MEGA

class SlideshowViewModelTests: XCTestCase {
    private var nodeEntities: [NodeEntity] {
        var nodes = [NodeEntity]()
        
        for i in 1...40 {
            nodes.append(NodeEntity(name: "\(i).png", handle: HandleEntity(i), isFile: true))
        }
        return nodes
    }
    
    private func makeSlideshowViewModel() throws -> SlideShowViewModel {
        SlideShowViewModel(
            dataSource: SlideShowDataSource(
                currentPhoto: try XCTUnwrap(nodeEntities.first),
                nodeEntities: nodeEntities,
                thumbnailUseCase: MockThumbnailUseCase(),
                advanceNumberOfPhotosToLoad: 20,
                numberOfUnusedPhotosBuffer: 20
            ),
            slideShowUseCase: MockSlideShowUseCase(slideShowRepository: MockSlideShowRepository.newRepo)
        )
    }

    func testSlideShowViewModel_play_playbackStatusShouldBePlaying() throws {
        let slideShowViewModel = try makeSlideshowViewModel()

        slideShowViewModel.dispatch(.play)
        XCTAssertTrue(slideShowViewModel.playbackStatus == .playing)
    }
    
    func testSlideShowViewModel_pause_playbackStatusShouldBePaused() throws {
        let slideShowViewModel = try makeSlideshowViewModel()
        slideShowViewModel.dispatch(.pause)

        XCTAssertTrue(slideShowViewModel.playbackStatus == .pause)
    }
    
    func testSlideShowViewModel_finish_playbackStatusShouldBeComplete() throws {
        let slideShowViewModel = try makeSlideshowViewModel()

        slideShowViewModel.dispatch(.finish)
        XCTAssertTrue(slideShowViewModel.playbackStatus == .complete)
    }
    
    func testSlideShowViewModel_resetTimer_playbackStatusShouldBePlaying() throws {
        let slideShowViewModel = try makeSlideshowViewModel()

        slideShowViewModel.dispatch(.play)
        slideShowViewModel.dispatch(.resetTimer)
        XCTAssertTrue(slideShowViewModel.playbackStatus == .playing)
    }
    
    func testSlideShowViewModel_cancel_playbackStatusShouldBePlaying() throws {
        let slideShowViewModel = try makeSlideshowViewModel()
        let sut: SlideShowViewModelPreferenceProtocol = slideShowViewModel
        
        slideShowViewModel.dispatch(.pause)
        XCTAssertTrue(slideShowViewModel.playbackStatus == .pause)
        
        sut.cancel()
        XCTAssertTrue(slideShowViewModel.playbackStatus == .playing)
    }
    
    func testSlideShowViewModel_restart_repeatShouldBeTrueAndTimeShouldBe8AndCurrentSlideShouldBeNeg1() throws {
        let slideShowViewModel = try makeSlideshowViewModel()
        let sut: SlideShowViewModelPreferenceProtocol = slideShowViewModel
        
        XCTAssertTrue(slideShowViewModel.playbackStatus == .initialized)
        slideShowViewModel.dispatch(.play)
        XCTAssertTrue(slideShowViewModel.playbackStatus == .playing)
        slideShowViewModel.dispatch(.pause)
        XCTAssertTrue(slideShowViewModel.playbackStatus == .pause)
        XCTAssertTrue(slideShowViewModel.currentSlideNumber == 0)
        XCTAssertTrue(slideShowViewModel.timeIntervalForSlideInSeconds == 4)
        XCTAssertTrue(slideShowViewModel.configuration.isRepeat == false)
        
        sut.restart(withConfig: SlideShowConfigurationEntity(
            playingOrder: .shuffled, timeIntervalForSlideInSeconds: .normal, isRepeat: true, includeSubfolders: false)
        )
        
        XCTAssertTrue(slideShowViewModel.playbackStatus == .playing)
        XCTAssertTrue(slideShowViewModel.timeIntervalForSlideInSeconds == 4)
        XCTAssertTrue(slideShowViewModel.configuration.isRepeat == true)
    }
}
